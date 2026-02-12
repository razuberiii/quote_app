module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: :update

    def index
      @users = User.includes(:company).order(:id)
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "Role updated."
      else
        @users = User.includes(:company).order(:id)
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:role)
    end
  end
end
