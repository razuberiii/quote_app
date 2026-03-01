module Users
  class SessionsController < Devise::SessionsController
    def create
      self.resource = warden.authenticate!(auth_options)

      # Check if email is verified
      if resource.email_verified_at.blank?
        sign_out(resource)
        redirect_to pending_email_verification_path, alert: "Please verify your email before logging in. A verification link has been sent to your email."
        return
      end

      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
