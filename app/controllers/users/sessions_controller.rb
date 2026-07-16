module Users
  class SessionsController < Devise::SessionsController
    def create
      # Keep existing clients and password managers that still submit `email`
      # compatible while the UI moves to the unified login field.
      login = params.dig(:user, :login).presence || params.dig(:user, :email).to_s
      if login.present? && !login.include?("@")
        params[:user][:email] = User.where("LOWER(username) = ?", login.strip.downcase).pick(:email) || login
      else
        params[:user][:email] = login
      end
      self.resource = warden.authenticate!(auth_options)

      # Check if email is verified
      if resource.email_verified_at.blank?
        service = EmailVerificationService.new(resource)
        auto_send_state = "failed"
        cooldown_seconds = EmailVerificationService.seconds_until_resend_allowed(resource)
        url_options = trusted_public_url_options

        if service.send_verification_email(url_options[:host], url_options[:protocol].to_sym)
          auto_send_state = "sent"
          cooldown_seconds = EmailVerificationService::RESEND_COOLDOWN_SECONDS
        else
          if cooldown_seconds.positive?
            auto_send_state = "cooldown"
          end
        end

        sign_out(resource)
        redirect_params = { email: resource.email, auto_send: auto_send_state }
        redirect_params[:cooldown] = cooldown_seconds if cooldown_seconds.to_i.positive?
        redirect_to pending_email_verification_path(redirect_params), alert: t("users.sessions.flash.verify_email_before_login")
        return
      end

      if resource.suspended?
        sign_out(resource)
        redirect_to suspended_path, alert: t("users.suspended.alert")
        return
      end

      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      resource.update_column(:last_login_at, Time.current)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
