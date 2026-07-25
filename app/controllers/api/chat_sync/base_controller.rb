module Api
  module ChatSync
    class BaseController < ActionController::API
      before_action :authenticate_chat_sync_token!

      private

      attr_reader :current_chat_token

      def authenticate_chat_sync_token!
        raw_token = request.authorization.to_s.sub(/\ABearer\s+/i, "")
        @current_chat_token = ChatSyncToken.authenticate(raw_token)
        unless @current_chat_token&.scopes&.include?("chat:sync")
          return render json: { error: "unauthorized" }, status: :unauthorized
        end

        @current_chat_token.touch_usage!
      end

      def current_user
        current_chat_token.user
      end

      def current_company
        current_chat_token.company
      end

      def current_binding
        current_company.chat_conversation_bindings.find(params[:binding_id] || params[:id])
      end
    end
  end
end
