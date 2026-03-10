class TeamInvitationsController < ApplicationController
  before_action :set_invitation, only: %i[destroy accept]
  before_action :require_company_team_manager!, only: %i[create destroy]

  def index
    @invitations = TeamInvitation.active
                                 .includes(:company, :invited_by)
                                 .where("LOWER(email) = ?", current_user.email.to_s.downcase)
                                 .order(created_at: :desc)
  end

  def create
    email = invitation_params[:email].to_s.strip.downcase
    role = invitation_params[:company_role].presence || "member"

    if current_user.company.users.where("LOWER(email) = ?", email).exists?
      redirect_to team_members_path, alert: t("team_invitations.flash.email_already_member") and return
    end

    existing_user = User.find_by("LOWER(email) = ?", email)
    if existing_user.blank?
      redirect_to team_members_path, alert: t("team_invitations.flash.no_account_found") and return
    end

    if existing_user.company_id == current_user.company_id
      redirect_to team_members_path, alert: t("team_invitations.flash.email_already_member") and return
    end

    invitation = current_user.company.team_invitations.active.find_by("LOWER(email) = ?", email)
    if invitation.present?
      redirect_to team_members_path, alert: t("team_invitations.flash.pending_invitation_exists") and return
    end

    @invitation = current_user.company.team_invitations.new(
      email: email,
      company_role: role,
      invited_by: current_user
    )

    if @invitation.save
      redirect_to team_members_path, notice: t("team_invitations.flash.invitation_created", email: email)
    else
      redirect_to team_members_path, alert: @invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @invitation.destroy
    redirect_to team_members_path, notice: t("team_invitations.flash.invitation_revoked")
  end

  def accept
    begin
      @invitation.accept!(current_user)
      redirect_to team_invitations_path, notice: t("team_invitations.flash.joined_company", company: @invitation.company.name)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to team_invitations_path, alert: t("team_invitations.flash.unable_accept", message: e.message)
    end
  end

  private

  def set_invitation
    @invitation = if action_name == "accept"
      TeamInvitation.find_by!(token: params[:token])
    else
      current_user.company.team_invitations.find_by!(token: params[:token])
    end
  end

  def invitation_params
    params.require(:team_invitation).permit(:email, :company_role)
  end
end
