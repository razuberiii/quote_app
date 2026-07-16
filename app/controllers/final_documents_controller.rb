class FinalDocumentsController < ApplicationController
  def create
    acceptance = current_user.company.quote_acceptances.find(params.require(:quote_acceptance_id))
    document = FinalDocumentGenerator.new(acceptance:, actor: current_user,
      document_type: params.require(:document_type), custom_title: params[:custom_title]).call
    redirect_to deal_path(document.quote, tab: "documents"), notice: "#{document.title} generated from the Acceptance snapshot."
  rescue ArgumentError, KeyError => error
    redirect_back fallback_location: deals_path, alert: error.message
  end

  def mark_sent
    document = current_user.company.final_documents.find(params[:id])
    document.update!(status: "sent", sent_at: Time.current)
    redirect_to deal_path(document.quote, tab: "documents"), notice: "Final document marked as sent."
  end
end
