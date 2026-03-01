module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :purge_avatar_if_requested, only: :update
    before_action :verify_turnstile, only: :create
    after_action :send_verification_email, only: :create, if: :successful_new_user_registration?

    def create
      build_resource(sign_up_params)

      # Call verify_turnstile before creating the user
      # (verify_turnstile will render :new if validation fails)

      resource.save
      if resource.persisted?
        # Email verification email will be sent via after_action
        # Redirect to pending verification page instead of auto-logging in
        yield resource if block_given?
        respond_with resource, location: pending_email_verification_path
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    protected

    def verify_turnstile
      # Skip Turnstile verification if disabled (useful for local development)
      if ENV["SKIP_TURNSTILE_VERIFICATION"] == "true"
        return
      end

      turnstile_token = params.dig(:user, :cf_turnstile_response)

      unless turnstile_token.present?
        @show_turnstile_modal = true
        @validation_error = "Bot verification is required. Please complete the CAPTCHA."
        build_resource
        render :new, status: :unprocessable_entity
        return
      end

      service = TurnstileVerificationService.new(turnstile_token, request.remote_ip)

      unless service.verify
        @show_turnstile_modal = true
        @validation_error = "Bot verification failed. Please try again."
        build_resource
        render :new, status: :unprocessable_entity
      end
    end

    def send_verification_email
      return unless resource.persisted?

      token = SecureRandom.hex(32)
      resource.update(
        email_verification_token: token,
        email_verification_token_sent_at: Time.current
      )

      # Create the verification URL with host and protocol
      verification_url = email_verification_url(
        token: token,
        protocol: request.scheme,
        host: request.host_with_port
      )

      EmailVerificationMailer.with(
        user: resource,
        verification_link: verification_url
      ).verification_email.deliver_later
    end

    def successful_new_user_registration?
      # This is called after the user is created
      true
    end

    def purge_avatar_if_requested
      return unless raw_account_update_params[:remove_avatar].to_s == "1"
      return unless current_user&.avatar&.attached?

      current_user.avatar.purge
    end

    def raw_account_update_params
      @raw_account_update_params ||= devise_parameter_sanitizer.sanitize(:account_update)
    end

    def account_update_params
      sanitized = raw_account_update_params.dup
      sanitized.delete(:remove_avatar)
      sanitized
    end

    def profile_only_update?(resource, params)
      params[:password].blank? &&
        params[:password_confirmation].blank? &&
        params[:current_password].blank? &&
        params[:email].to_s.casecmp(resource.email.to_s).zero?
    end
  end
end
