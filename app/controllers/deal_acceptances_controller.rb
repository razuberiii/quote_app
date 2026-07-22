class DealAcceptancesController < ApplicationController
  before_action :load_deal

  def new
    @version = @deal.quote_revisions.find(params[:version_id].presence || @deal.quote_revisions.maximum(:id))
    @acceptance = QuoteAcceptance.new(accepted_at: Time.current, quote_revision: @version,
      name: @deal.customer&.contact_name, email: @deal.customer&.email, buyer_company: @deal.customer&.name)
  end

  def create
    version = @deal.quote_revisions.find(params.require(:quote_acceptance).require(:quote_revision_id))
    acceptance = ExternalAcceptanceRecorder.new(revision: version, actor: current_user,
      attributes: acceptance_params.to_h.symbolize_keys, idempotency_key: params[:idempotency_key]).call
    redirect_to quote_path(@deal), notice: I18n.t("self_service.quote_core.acceptance_recorded", number: version.number)
  rescue ExternalAcceptanceRecorder::NotActionable, ActiveRecord::RecordInvalid => error
    redirect_to new_acceptance_quote_path(@deal, version_id: version&.id), alert: error.message
  end

  private

  def load_deal
    @deal = current_user.company.quotes.find(params[:deal_id] || params[:id])
  end

  def acceptance_params
    params.require(:quote_acceptance).permit(:quote_revision_id, :acceptance_method, :name, :email,
      :buyer_company, :accepted_at, :po_number, :note, :evidence_summary, :has_differences, evidence_files: [])
  end
end
