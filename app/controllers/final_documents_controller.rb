class FinalDocumentsController < ApplicationController
  before_action :load_document, only: %i[show pdf email mark_sent]

  def show; end

  def create
    acceptance = current_user.company.quote_acceptances.find(params.require(:quote_acceptance_id))
    document = FinalDocumentGenerator.new(acceptance:, actor: current_user,
      document_type: params.require(:document_type), custom_title: params[:custom_title]).call
    redirect_to final_document_path(document), notice: "#{document.title} generated from the immutable Acceptance snapshot."
  rescue StandardError => error
    redirect_back fallback_location: deals_path, alert: "Final document generation failed: #{error.message}"
  end

  def pdf
    raise ActiveRecord::RecordNotFound unless @document.file.attached?
    send_data @document.file.download, filename: @document.file.filename.to_s,
      type: "application/pdf", disposition: params[:preview] == "1" ? "inline" : "attachment"
  end

  def email
    delivery = @document.quote_revision.version_deliveries.create!(company: @document.company, quote: @document.quote,
      created_by: current_user, channel: "email_pdf", execution_type: "system", status: "queued",
      recipient: params.require(:recipient), cc: params[:cc], subject: params.require(:subject),
      message_body: params.require(:message_body), idempotency_key: request.request_id)
    delivery.generated_file.attach(@document.file.blob)
    VersionDeliveryMailer.with(delivery:).deliver_version.deliver_now
    delivery.update!(status: "sent", delivered_at: Time.current, file_name: @document.file_name, file_size: @document.file_size)
    @document.update!(status: "sent", sent_at: Time.current)
    redirect_to final_document_path(@document), notice: "Final document email sent."
  rescue StandardError => error
    delivery&.update_columns(status: "failed", error_message: error.message.to_s.first(1_000), updated_at: Time.current)
    redirect_to final_document_path(@document), alert: "Email failed: #{error.message}"
  end

  def mark_sent
    @document.update!(status: "sent", sent_at: Time.current)
    redirect_to final_document_path(@document), notice: "External delivery recorded."
  end

  private

  def load_document
    @document = current_user.company.final_documents.includes(quote_acceptance: :quote_revision).find(params[:id])
  end
end
