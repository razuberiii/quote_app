class TeamMembersController < ApplicationController
  before_action :require_company_team_manager!
  before_action :set_member, only: %i[show update destroy]

  def index
    @members = current_user.company.users.order(:company_role, :id)
    @new_invitation = TeamInvitation.new(company_role: "member")
    @pending_invitations = current_user.company.team_invitations.active.order(created_at: :desc)
  end

  def show; end

  def update
    requested_role = member_params[:company_role].to_s
    unless %w[admin member].include?(requested_role)
      redirect_to team_members_path, alert: "Only admin/member can be assigned from this screen." and return
    end

    if @member.company_owner?
      redirect_to team_members_path, alert: "Owner role cannot be changed here." and return
    end

    if @member == current_user
      redirect_to team_members_path, alert: "You cannot change your own role." and return
    end

    if @member.update(company_role: requested_role)
      redirect_to team_members_path, notice: "Member role updated."
    else
      @members = current_user.company.users.order(:company_role, :id)
      @new_invitation = TeamInvitation.new(company_role: "member")
      @pending_invitations = current_user.company.team_invitations.active.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    if @member.company_owner?
      redirect_to team_members_path, alert: "Owner cannot be removed." and return
    end

    if @member == current_user
      redirect_to team_members_path, alert: "You cannot remove yourself." and return
    end

    email = @member.email
    @member.move_to_personal_company!
    redirect_to team_members_path, notice: "Removed from team: #{email}. Account preserved."
  end

  private

  def set_member
    @member = current_user.company.users.find(params[:id])
  end

  def member_params
    params.require(:user).permit(:company_role)
  end
end
