module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :purge_avatar_if_requested, only: :update

    protected

    # Allow profile-only updates without asking for current password.
    def update_resource(resource, params)
      if profile_only_update?(resource, params)
        resource.update_without_password(params.except(:current_password, :password, :password_confirmation))
      else
        super
      end
    end

    private

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
