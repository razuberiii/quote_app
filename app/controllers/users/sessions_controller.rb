module Users
  class SessionsController < Devise::SessionsController
    def create
      self.resource = warden.authenticate!(auth_options)

      # Check if email is verified
      if resource.email_verified_at.blank?
        service = EmailVerificationService.new(resource)
        auto_send_state = "failed"
        cooldown_seconds = nil

        if service.send_verification_email(request.host_with_port, request.scheme.to_sym)
          auto_send_state = "sent"
        else
          seconds_left = EmailVerificationService.seconds_until_resend_allowed(resource)
          if seconds_left.positive?
            auto_send_state = "cooldown"
            cooldown_seconds = seconds_left
          end
        end

        sign_out(resource)
        redirect_params = { email: resource.email, auto_send: auto_send_state }
        redirect_params[:cooldown] = cooldown_seconds if cooldown_seconds.present?
        redirect_to pending_email_verification_path(redirect_params), alert: t("users.sessions.flash.verify_email_before_login")
        return
      end

      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
