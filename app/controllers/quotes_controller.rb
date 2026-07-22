class QuotesController < ApplicationController
  before_action :set_quote, except: :index
  before_action :set_form_context, only: %i[edit update]
  before_action :set_seller_locale, only: :preview
  before_action :use_buyer_locale, only: :preview

  def index
    @quotes = current_user.company.quotes.not_archived.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :buyer_activities, quote_revisions: %i[buyer_questions change_requests version_deliveries]).order(updated_at: :desc)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @quotes = @quotes.left_joins(:customer, :quote_items).where(
        "customers.name ILIKE :term OR quotes.quote_no ILIKE :term OR quotes.custom_title ILIKE :term OR quote_items.description ILIKE :term",
        term:
      ).distinct
    end
    @quotes = @quotes.where(status: quote_status_scope(params[:status])) if quote_status_scope(params[:status])
    @quote_rows = @quotes.map { |quote| [ quote, QuoteLifecycle.new(quote).call ] }
  end

  def show
    @lifecycle = QuoteLifecycle.new(@quote).call
    @versions = @quote.quote_revisions.where.not(published_at: nil).ordered
    @questions = BuyerQuestion.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @requests = ChangeRequest.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @responses = @quote.deal_responses.includes(attachment_attachment: :blob).order(received_at: :desc)
    @deliveries = @quote.version_deliveries.order(delivered_at: :desc)
    @activities = @quote.buyer_activities.order(created_at: :desc).limit(40)
    @acceptance = @quote.quote_acceptance
    @tab = params[:tab].presence_in(%w[quote activity versions]) || "quote"
    @published_revision = @versions.find_by(id: params[:published_revision_id])
  end

  def publish
    @revisions = @quote.quote_revisions.where.not(published_at: nil).ordered
    @readiness_issues = QuoteReadinessAudit.new(@quote).issues
    render :publish
  end

  def reply_question
    question = BuyerQuestion.where(quote_revision_id: @quote.quote_revisions.select(:id)).find(params[:question_id])
    question.update!(seller_reply: params.require(:buyer_question).require(:seller_reply), replied_at: Time.current)
    redirect_to quote_path(@quote, tab: "activity"), notice: t("self_service.quote_core.reply_saved")
  end

  def apply_change_request
    request_record = ChangeRequest.where(quote_revision_id: @quote.quote_revisions.select(:id)).find(params[:change_request_id])
    quantities = request_record.requested_changes.to_h.fetch("quantities", {})
    @quote.quote_items.each_with_index do |item, index|
      requested = quantities[index.to_s].to_i
      item.update!(quantity: requested) if requested.positive? && requested != item.quantity.to_i
    end
    request_record.update!(status: "reviewed")
    @quote.update!(status: "negotiating", studio_state: "draft")
    redirect_to edit_quote_path(@quote, source_version: request_record.quote_revision.number),
      notice: t("self_service.quote_core.change_request_applied", number: request_record.quote_revision.number)
  end

  def preview
    snapshot = QuoteSnapshotBuilder.new(@quote).as_json
    @revision = QuoteRevision.new(company: @quote.company, quote: @quote,
      number: (@quote.quote_revisions.maximum(:number) || 0) + 1,
      status: "draft", currency: @quote.currency, total: @quote.grand_total,
      snapshot:, secure_token: "working-preview", expires_at: @quote.valid_until&.end_of_day)
    @snapshot = snapshot
    @state = "preview"
    @readiness_issues = QuoteReadinessAudit.new(@quote).issues
    render "buyer_rooms/show", layout: "buyer_room"
  end

  def edit
    return redirect_to quote_path(@quote), alert: t("self_service.quote_core.immutable_edit") unless @quote.can_edit_revision?
    ensure_item
    @readiness_issues = QuoteReadinessAudit.new(@quote).issues
  end

  def update
    return redirect_to quote_path(@quote), alert: t("self_service.quote_core.immutable_edit") unless @quote.can_edit_revision?
    @quote.assign_attributes(quote_params)
    if @quote.save
      redirect_to edit_quote_path(@quote), status: :see_other, notice: t("self_service.quote_core.draft_saved")
    else
      ensure_item
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_quote
    @quote = current_user.company.quotes.not_archived.includes({ quote_items: [ :product, { item_image_attachment: :blob } ] }, :customer, :template).find(params[:id])
  end

  def quote_status_scope(value)
    {
      "draft" => %w[draft ready pending],
      "sent" => %w[sent],
      "viewed" => %w[viewed],
      "changes" => %w[revision_requested negotiating],
      "accepted" => %w[accepted awaiting_deposit won],
      "expired" => %w[expired archived cancelled lost]
    }[value.to_s]
  end

  def set_form_context
    @products = current_user.company.products.with_attached_image.with_attached_gallery_images.order(:name)
    @quote_presets_by_module = QuotePreset::MODULE_KEYS.index_with { [] }
    @quote_preset_master = current_user.company.quote_preset_master
    @readiness_issues = QuoteReadinessAudit.new(@quote).issues
  end

  def ensure_item
    @quote.quote_items.build unless @quote.quote_items.reject(&:marked_for_destruction?).any?
  end

  def quote_params
    params.require(:quote).permit(:currency, :buyer_locale, :issued_on, :valid_until, :payment_term, :trade_term,
      :custom_title, :notes, :tax_amount, :shipping_amount, :shipping_price_source,
      :discount_amount, :terms_text, :delivery_notes,
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity,
        :item_type, :specifications_text, :addon_charges_text, :item_image,
        :item_image_blob_id, :remove_item_image, :price_source, :selection_mode,
        :sku_snapshot, :unit_snapshot, :lead_time_snapshot, :packing_snapshot,
        :_destroy, { buyer_options: {} } ])
  end

  def use_buyer_locale
    I18n.locale = @quote.buyer_locale.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end

  def set_seller_locale
    @seller_locale = current_user.language.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end
end
