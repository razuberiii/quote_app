module Api
  module ChatSync
    class MessagesController < BaseController
      def create
        binding = current_binding
        return render json: { error: "binding_paused" }, status: :conflict if binding.paused?

        request_id = params.require(:requestId).to_s
        existing = binding.chat_sync_requests.find_by(request_id:)
        return render json: receipt(existing, binding:, duplicate: true) if existing

        ChatConversationTaskRouter.new(binding:, user: current_user, messages: params[:messages]).call
        accepted = ChatMessageIngestor.new(binding:, user: current_user, messages: params[:messages]).call
        request_record = binding.chat_sync_requests.create!(request_id:, accepted_count: accepted.size)
        binding.update!(last_synced_at: Time.current)
        render json: receipt(request_record, binding:, duplicate: false).merge(
          acceptedLocalIds: accepted.map(&:local_id),
          messageCursor: binding.chat_captured_messages.maximum(:id)
        ), status: :created
      rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
        render json: { error: "invalid_batch", details: error.message }, status: :unprocessable_entity
      end

      private

      def receipt(request_record, binding:, duplicate:)
        {
          requestId: request_record.request_id,
          acceptedCount: request_record.accepted_count,
          messageCount: binding.chat_captured_messages.count,
          duplicateRequest: duplicate
        }
      end
    end
  end
end
