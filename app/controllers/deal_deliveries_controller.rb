class DealDeliveriesController < ApplicationController
  before_action :load_deal_and_version

  def new
    @delivery = VersionDelivery.new(recipient: @deal.customer&.email, delivered_at: Time.current)
  end

  def create
    @delivery = @version.version_deliveries.new(delivery_params.merge(
      company: current_user.company, quote: @deal, created_by: current_user,
      idempotency_key: params[:idempotency_key].presence || request.request_id
    ))
    @delivery.evidence.attach(params.dig(:version_delivery, :evidence)) if params.dig(:version_delivery, :evidence).present?
    @delivery.save!
    @deal.update!(status: "sent", sent_at: @delivery.delivered_at) if @delivery.status == "succeeded"
    @deal.buyer_activities.create!(quote_revision: @version, kind: @delivery.status == "failed" ? "delivery_failed" : "delivered",
      metadata: { channel: @delivery.channel, external_channel: @delivery.external_channel },
      deduplication_key: "delivery:#{@delivery.id}")
    redirect_to deal_path(@deal), notice: "Delivery recorded against Version #{@version.number}."
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def load_deal_and_version
    @deal = current_user.company.quotes.find(params[:deal_id] || params[:id])
    @version = @deal.quote_revisions.find(params[:version_id].presence || @deal.quote_revisions.maximum(:id))
  end

  def delivery_params
    params.require(:version_delivery).permit(:channel, :external_channel, :recipient, :status, :note, :delivered_at)
  end
end
