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

  private

  def load_deal
    @deal = current_user.company.quotes.find(params[:deal_id] || params[:id])
  end

  def response_params
    params.require(:deal_response).permit(:quote_revision_id, :kind, :source, :buyer_name, :buyer_email,
      :context_type, :context_key, :body, :received_at)
  end
end
