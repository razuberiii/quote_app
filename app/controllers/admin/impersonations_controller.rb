module Admin
  class ImpersonationsController < ApplicationController
    before_action :ensure_impersonation_session!

    def destroy
      admin_actor = real_admin_user
      target_user = current_user

      Admin::AuditLogger.log!(
        actor: admin_actor,
        target: target_user,
        action: :impersonation_stopped,
        metadata: {
          impersonated_user_id: target_user.id,
          impersonated_user_email: target_user.email
        }
      )

      sign_in(:user, admin_actor)
      clear_impersonation_session!
      redirect_to admin_root_path, notice: t("admin.impersonation.flash.stopped")
    end

    private

    def ensure_impersonation_session!
      return if impersonating? && real_admin_user&.admin?

      redirect_to root_path, alert: t("flash.not_authorized")
    end
  end
end
