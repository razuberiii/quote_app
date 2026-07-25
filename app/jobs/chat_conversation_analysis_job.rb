class ChatConversationAnalysisJob < ApplicationJob
  queue_as :default

  retry_on InquiryAiExtractor::ResponseError, wait: 30.seconds, attempts: 2

  def perform(binding_id)
    binding = ChatConversationBinding.find(binding_id)
    latest = binding.inquiry.inquiry_messages.order(:id).last
    InquiryConversationUpdater.new(binding.inquiry, latest).call if latest
    complete(binding)
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError
    binding&.inquiry&.manually_extract!
    complete(binding) if binding
  rescue StandardError => error
    binding&.update!(analysis_result: {
      "status" => "failed", "errorCode" => error.class.name, "analysisVersion" => "chat-readiness-v1"
    })
    raise
  end

  private

  def complete(binding)
    result = ChatReadinessAnalysis.new(binding).call
    binding.update!(analysis_result: result, last_analyzed_at: Time.current,
      analyzed_message_cursor: result["analyzedMessageCursor"])
  end
end
