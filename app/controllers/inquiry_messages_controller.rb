class InquiryMessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    inquiry = current_user.company.inquiries.find(params[:inquiry_id])
    message = inquiry.inquiry_messages.new(message_params.merge(recorded_by: current_user, occurred_at: Time.current))
    message.attachment.attach(params.dig(:inquiry_message, :attachment)) if params.dig(:inquiry_message, :attachment).present?
    if message.body.blank? && message.attachment.attached?
      message.body = InquirySourceReader.new(message.attachment).call
    end
    message.change_summary = { "status" => "queued" }
    message.save!
    InquiryConversationAnalysisJob.set(wait: 12.seconds).perform_later(inquiry.id, message.id)
    redirect_to inquiry_path(inquiry, anchor: "conversation"), notice: t("self_service.conversation.queued")
  rescue InquirySourceReader::UnsupportedFile, InquirySourceReader::UnreadableFile
    redirect_to inquiry_path(inquiry, anchor: "conversation"), alert: t("self_service.conversation.invalid_file")
  rescue ActiveRecord::RecordInvalid
    redirect_to inquiry_path(inquiry, anchor: "conversation"), alert: t("self_service.conversation.invalid_message")
  end

  private

  def message_params
    permitted = params.require(:inquiry_message).permit(:direction, :channel, :body, :attachment)
    permitted[:direction] = "buyer" if permitted[:direction].blank?
    permitted[:channel] = permitted[:attachment].present? ? "file" : "text" if permitted[:channel].blank?
    permitted
  end
end
