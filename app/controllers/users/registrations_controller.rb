module Users
  class RegistrationsController < Devise::RegistrationsController
    include TurnstileVerifiable

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
        respond_with resource, location: pending_email_verification_path(email: resource.email)
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    protected

    def verify_turnstile
      turnstile_token = params.dig(:user, :cf_turnstile_response)
      unless verify_turnstile_for_html!(
        token: turnstile_token,
        on_missing: -> {
          @show_turnstile_modal = true
          @validation_error = "Bot verification is required. Please complete the CAPTCHA."
          build_resource
          render :new, status: :unprocessable_entity
        },
        on_failed: -> {
          @show_turnstile_modal = true
          @validation_error = "Bot verification failed. Please try again."
          build_resource
          render :new, status: :unprocessable_entity
        }
      )
        return
      end
    end

    def send_verification_email
      return unless resource.persisted?

      service = EmailVerificationService.new(resource)
      service.send_verification_email(request.host_with_port, request.scheme.to_sym)
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

    def update_resource(resource, params)
      if profile_only_update?(resource, params)
        profile_params = params.except(:current_password, :password, :password_confirmation)
        resource.update_without_password(profile_params)
      else
        resource.update_with_password(params)
      end
    end
  end
end
