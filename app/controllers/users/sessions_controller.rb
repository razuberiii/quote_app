module Users
  class SessionsController < Devise::SessionsController
    def create
      self.resource = warden.authenticate!(auth_options)

      # Check if email is verified
      if resource.email_verified_at.blank?
        EmailVerificationService.new(resource).send_verification_email(request.host_with_port, request.scheme.to_sym)
        sign_out(resource)
        redirect_to pending_email_verification_path(email: resource.email), alert: "Please verify your email before logging in."
        return
      end

      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
