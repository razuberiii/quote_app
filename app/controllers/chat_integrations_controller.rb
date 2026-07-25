class ChatIntegrationsController < ApplicationController
  before_action :authenticate_user!

  def show
    @tokens = current_user.chat_sync_tokens.order(created_at: :desc)
  end

  def create_pairing_code
    current_user.chat_pairing_codes.where(used_at: nil).delete_all
    render json: { code: ChatPairingCode.issue!(current_user), expiresIn: ChatPairingCode::TTL.to_i }
  end

  def revoke
    current_user.chat_sync_tokens.find(params[:id]).update!(revoked_at: Time.current)
    redirect_to chat_integration_path, notice: t("chat_sync.revoked")
  end
end
