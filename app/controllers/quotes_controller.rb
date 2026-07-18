class QuotesController < ApplicationController
  before_action :set_quote
  before_action :set_form_context, only: %i[edit update]

  def show
    @revisions = @quote.quote_revisions.ordered
    @readiness_issues = QuoteReadinessAudit.new(@quote).issues
  end

  def preview
    snapshot = QuoteSnapshotBuilder.new(@quote).as_json
    @revision = QuoteRevision.new(company: @quote.company, quote: @quote,
      number: (@quote.quote_revisions.maximum(:number) || 0) + 1,
      status: "draft", currency: @quote.currency, total: @quote.grand_total,
      snapshot:, secure_token: "working-preview", expires_at: @quote.valid_until&.end_of_day)
    @snapshot = snapshot
    @state = "preview"
    render "buyer_rooms/show", layout: "buyer_room"
  end

  def edit
    return redirect_to quote_path(@quote), alert: "Published content is immutable. Prepare an update from the Deal instead." unless @quote.can_edit_revision?
    ensure_item
  end

  def update
    return redirect_to quote_path(@quote), alert: "Published content is immutable. Prepare an update from the Deal instead." unless @quote.can_edit_revision?
    @quote.assign_attributes(quote_params)
    if @quote.save
      redirect_to edit_quote_path(@quote), status: :see_other, notice: "Working draft saved."
    else
      ensure_item
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_quote
    @quote = current_user.company.quotes.not_archived.includes({ quote_items: [ :product, { item_image_attachment: :blob } ] }, :customer, :template).find(params[:id])
  end

  def set_form_context
    @products = current_user.company.products.with_attached_image.with_attached_gallery_images.order(:name)
    @template_options = current_user.company.quote_templates.ordered
    @quote_presets_by_module = QuotePreset::MODULE_KEYS.index_with { [] }
    @quote_preset_master = current_user.company.quote_preset_master
  end

  def ensure_item
    @quote.quote_items.build unless @quote.quote_items.reject(&:marked_for_destruction?).any?
  end

  def quote_params
    params.require(:quote).permit(:currency, :issued_on, :valid_until, :payment_term, :trade_term,
      :custom_title, :notes, :tax_amount, :shipping_amount, :shipping_price_source,
      :discount_amount, :terms_text, :delivery_notes,
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity,
        :item_type, :specifications_text, :addon_charges_text, :item_image,
        :item_image_blob_id, :remove_item_image, :price_source, :selection_mode,
        :sku_snapshot, :unit_snapshot, :lead_time_snapshot, :packing_snapshot,
        :_destroy, { buyer_options: {} } ])
  end
end
