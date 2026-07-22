class InquiryMessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    inquiry = current_user.company.inquiries.find(params[:inquiry_id])
    message = inquiry.inquiry_messages.new(message_params.merge(recorded_by: current_user, occurred_at: Time.current))
    message.attachment.attach(params.dig(:inquiry_message, :attachment)) if params.dig(:inquiry_message, :attachment).present?
    if message.body.blank? && message.attachment.attached?
      message.body = InquirySourceReader.new(message.attachment).call
    end
    message.save!
    InquiryConversationUpdater.new(inquiry, message).call
    redirect_to inquiry_path(inquiry, anchor: "conversation"), notice: t("self_service.conversation.added")
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError => error
    inquiry&.manually_extract!
    redirect_to inquiry_path(inquiry, anchor: "conversation"), alert: t("self_service.conversation.fallback")
  rescue InquirySourceReader::UnsupportedFile, InquirySourceReader::UnreadableFile
    redirect_to inquiry_path(inquiry, anchor: "conversation"), alert: t("self_service.conversation.invalid_file")
  rescue ActiveRecord::RecordInvalid
    redirect_to inquiry_path(inquiry, anchor: "conversation"), alert: t("self_service.conversation.invalid_message")
  end

  private

  def message_params
    params.require(:inquiry_message).permit(:direction, :channel, :body, :attachment)
  end
end
