module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: :update

    def index
      @users = User.includes(:company).order(:id)
    end

    def update
      @user.role = role_param

      if @user.save
        redirect_to admin_users_path, notice: t("admin.users.flash.role_updated")
      else
        @users = User.includes(:company).order(:id)
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def role_param
      role = params.require(:user).fetch(:role).to_s
      return role if User.roles.key?(role)

      raise ActionController::BadRequest, "Invalid role"
    end
  end
end
