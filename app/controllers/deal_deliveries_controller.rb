class DealDeliveriesController < ApplicationController
  before_action :load_deal
  before_action :load_version, only: %i[new create update_link]

  def new
    @delivery = VersionDelivery.new(recipient: @deal.customer&.email,
      subject: "Quotation #{@deal.quote_no} · Version #{@version.number}",
      message_body: "Hello #{@deal.customer&.contact_name.presence || @deal.customer&.name},\n\nPlease review the attached quotation.")
  end

  def create
    channel = params.require(:version_delivery).require(:channel)
    delivery = @version.version_deliveries.new(base_attributes(channel))
    if VersionDelivery::EXTERNAL_CHANNELS_LIST.include?(channel)
      delivery.assign_attributes(external_attributes.merge(status: "externally_sent", execution_type: "manual",
        delivered_at: external_attributes[:delivered_at].presence || Time.current))
      delivery.evidence.attach(params.dig(:version_delivery, :evidence)) if params.dig(:version_delivery, :evidence).present?
      delivery.save!
    else
      delivery.assign_attributes(system_attributes.merge(status: "draft", execution_type: "system"))
      delivery.save!
      VersionDeliveryExecutor.new(delivery).call
    end
    mark_deal_delivered(delivery) if delivery.successful?
    redirect_to delivery_destination(delivery), notice: delivery_notice(delivery)
  rescue StandardError => error
    redirect_to deliver_deal_path(@deal, version_id: @version.id), alert: "Delivery failed: #{error.message}"
  end

  def download
    delivery = @deal.version_deliveries.find(params[:delivery_id])
    raise ActiveRecord::RecordNotFound unless delivery.generated_file.attached?
    delivery.update!(status: "downloaded") if delivery.status == "generated"
    send_data delivery.generated_file.download, filename: delivery.generated_file.filename.to_s,
      type: delivery.generated_file.content_type, disposition: "attachment"
  end

  def retry
    previous = @deal.version_deliveries.find(params[:delivery_id])
    delivery = previous.dup
    delivery.assign_attributes(status: "draft", error_message: nil, delivered_at: nil, retry_of: previous,
      idempotency_key: request.request_id)
    delivery.save!
    VersionDeliveryExecutor.new(delivery).call
    mark_deal_delivered(delivery)
    redirect_to deal_path(@deal, tab: "documents"), notice: "Delivery retry sent successfully."
  rescue StandardError => error
    redirect_to deal_path(@deal, tab: "documents"), alert: "Retry failed: #{error.message}"
  end

  def update_link
    case params.require(:link_action)
    when "revoke"
      @version.update!(revoked_at: Time.current, status: "revoked")
    when "regenerate"
      @version.update!(secure_token: SecureRandom.urlsafe_base64(32), revoked_at: nil, status: "current")
    end
    redirect_to deliver_deal_path(@deal, version_id: @version.id), notice: "Buyer Room link updated."
  end

  private

  def load_deal
    @deal = current_user.company.quotes.find(params[:deal_id] || params[:id])
  end

  def load_version
    @version = @deal.quote_revisions.find(params[:version_id].presence || @deal.quote_revisions.maximum(:id))
    raise ActiveRecord::RecordNotFound if @version.published_at.blank?
  end

  def base_attributes(channel)
    { company: current_user.company, quote: @deal, created_by: current_user, channel:,
      idempotency_key: params[:idempotency_key].presence || request.request_id }
  end

  def system_attributes
    params.require(:version_delivery).permit(:recipient, :subject, :message_body, :cc)
  end

  def external_attributes
    params.require(:version_delivery).permit(:external_channel, :recipient, :note, :delivered_at)
  end

  def mark_deal_delivered(delivery)
    @deal.update!(status: "sent", sent_at: delivery.delivered_at || Time.current)
    @deal.buyer_activities.create!(company: @deal.company, quote_revision: delivery.quote_revision, kind: "delivered",
      metadata: { channel: delivery.channel, external_channel: delivery.external_channel },
      deduplication_key: "delivery:#{delivery.id}")
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def delivery_destination(delivery)
    delivery.generated_file.attached? ? deal_path(@deal, tab: "documents") : deal_path(@deal)
  end

  def delivery_notice(delivery)
    return "Version delivered successfully." if delivery.successful?
    return "File generated from immutable Version #{delivery.quote_revision.number}." if delivery.status == "generated"
    "Delivery recorded."
  end
end
