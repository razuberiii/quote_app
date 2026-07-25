module Api
  module ChatSync
    class PairingsController < ActionController::API
      def create
        pairing = ChatPairingCode.consume!(params.require(:code))
        token, raw_token = ChatSyncToken.issue!(pairing, label: params[:label].to_s.first(80))
        render json: {
          token: raw_token, expiresAt: token.expires_at.iso8601,
          user: { id: token.user_id, email: token.user.email },
          company: { id: token.company_id, name: token.company.name }
        }, status: :created
      rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
        render json: { error: "invalid_or_expired_code" }, status: :unprocessable_entity
      end
    end
  end
end
