module Api
  module ChatSync
    class AnalysesController < BaseController
      def create
        binding = current_binding
        result = ChatConversationAnalysisScheduler.new(binding).call
        render json: result, status: :accepted
      rescue ChatConversationAnalysisScheduler::NoMessages
        render json: { error: "no_messages" }, status: :unprocessable_entity
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
