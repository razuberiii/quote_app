class DealResponsesController < ApplicationController
  before_action :load_deal

  def new
    @version = @deal.quote_revisions.find(params[:version_id].presence || @deal.quote_revisions.maximum(:id))
    @response = DealResponse.new(received_at: Time.current, quote_revision: @version)
  end

  def create
    @version = @deal.quote_revisions.find(params.require(:deal_response).require(:quote_revision_id))
    @response = @deal.deal_responses.new(response_params.merge(
      company: current_user.company, quote_revision: @version, recorded_by: current_user,
      idempotency_key: params[:idempotency_key].presence || request.request_id
    ))
    @response.attachment.attach(params.dig(:deal_response, :attachment)) if params.dig(:deal_response, :attachment).present?
    @response.save!
    @response.update!(difference_review: DealResponseAnalyzer.new(@response).call)
    redirect_to deal_path(@deal, tab: "conversation"), notice: "Buyer response added to this Deal."
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def apply
    response = @deal.deal_responses.find(params[:response_id])
    raise ActionController::BadRequest, "Only reviewed differences can be applied" if response.difference_review["changes"].blank?
    WorkingUpdateApplier.new(response:, selected_paths: params[:selected_paths]).call
    redirect_to edit_quote_path(@deal, applied_response_id: response.id), notice: "Selected buyer changes are highlighted in the Working update draft."
  end

  def disposition
    response = @deal.deal_responses.find(params[:response_id])
    status = params.require(:status).presence_in(%w[reviewed evidence_only])
    raise ActionController::BadRequest, "Invalid response disposition" unless status
    response.update!(status:)
    redirect_to deal_path(@deal, tab: "conversation"), notice: status == "evidence_only" ? "Kept as evidence; the published Version was not changed." : "Response review completed."
  end

  private

  def load_deal
    @deal = current_user.company.quotes.find(params[:deal_id] || params[:id])
  end

  def response_params
    params.require(:deal_response).permit(:quote_revision_id, :kind, :source, :buyer_name, :buyer_email,
      :context_type, :context_key, :body, :received_at)
  end
end
