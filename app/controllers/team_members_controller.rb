class TeamMembersController < ApplicationController
  before_action :require_company_team_manager!
  before_action :set_member, only: %i[show update destroy]

  def index
    @members = current_user.company.users.order(:company_role, :id)
  end

  def show; end

  def update
    requested_role = member_params[:company_role].to_s
    unless %w[admin member].include?(requested_role)
      redirect_to team_members_path, alert: t("team_members.flash.only_admin_member") and return
    end

    if @member.company_owner?
      redirect_to team_members_path, alert: t("team_members.flash.owner_role_cannot_change") and return
    end

    if @member == current_user
      redirect_to team_members_path, alert: t("team_members.flash.cannot_change_own_role") and return
    end

    if @member.update(company_role: requested_role)
      redirect_to team_members_path, notice: t("team_members.flash.member_role_updated")
    else
      @members = current_user.company.users.order(:company_role, :id)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    if @member.company_owner?
      redirect_to team_members_path, alert: t("team_members.flash.owner_cannot_removed") and return
    end

    if @member == current_user
      redirect_to team_members_path, alert: t("team_members.flash.cannot_remove_self") and return
    end

    email = @member.email
    @member.move_to_personal_company!
    redirect_to team_members_path, notice: t("team_members.flash.removed_from_team", email: email)
  end

  private

  def set_member
    @member = current_user.company.users.find(params[:id])
  end

  def member_params
    params.require(:user).permit(:company_role)
  end
end
