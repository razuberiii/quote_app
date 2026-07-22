class InquiryConversationAnalysisJob < ApplicationJob
  queue_as :default

  retry_on InquiryAiExtractor::ResponseError, wait: 30.seconds, attempts: 2

  def perform(inquiry_id, message_id)
    inquiry = Inquiry.find(inquiry_id)
    message = inquiry.inquiry_messages.find(message_id)
    newer_pending = inquiry.inquiry_messages.where("id > ?", message.id)
      .where("change_summary ->> 'status' = ?", "queued").exists?
    return if newer_pending

    pending = inquiry.inquiry_messages.where("change_summary ->> 'status' = ?", "queued").to_a
    result = InquiryConversationUpdater.new(inquiry, message).call
    pending.each { |entry| entry.update!(change_summary: result.merge("status" => "complete")) }
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError => error
    inquiry&.manually_extract!
    message&.update!(change_summary: { "status" => "fallback", "error" => error.class.name })
  end
end
