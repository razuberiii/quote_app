class InitialInquiryAnalysisJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(inquiry_id)
    inquiry = Inquiry.find(inquiry_id)
    inquiry.extract_requirements!
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError => error
    inquiry&.manually_extract!
    Rails.logger.warn("Initial inquiry AI extraction failed: #{error.class}: #{error.message}")
  end
end
