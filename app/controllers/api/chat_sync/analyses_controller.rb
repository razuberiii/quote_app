module Api
  module ChatSync
    class AnalysesController < BaseController
      def create
        binding = current_binding
        cursor = binding.chat_captured_messages.maximum(:id)
        return render json: { error: "no_messages" }, status: :unprocessable_entity unless cursor

        binding.update!(analysis_result: {
          "status" => "queued", "requestedAt" => Time.current.iso8601,
          "messageCursor" => cursor
        })
        ChatConversationAnalysisJob.perform_later(binding.id)
        render json: { status: "queued", messageCursor: cursor }, status: :accepted
      end

      def show
        binding = current_binding
        render json: {
          status: binding.analysis_result["status"] || "idle",
          result: binding.analysis_result,
          lastAnalyzedAt: binding.last_analyzed_at&.iso8601
        }
      end
    end
  end
end
