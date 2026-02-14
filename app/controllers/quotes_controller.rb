class QuotesController < ApplicationController
  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate share update_template]
  before_action :set_template, only: %i[show export_pdf export_xlsx update_template]
  before_action :set_form_products, only: %i[new edit create update duplicate]
  before_action :set_template_options, only: %i[new edit create update show duplicate update_template]

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.latest_versions
    redirect_to @customer
  end

  def new
    @quote = @customer.quotes.new(currency: "USD", status: "pending", template: current_user.company.quote_template_or_default)
    ensure_quote_item_row
  end

  def create
    unless current_user.can_create_quote?
      used = current_user.quote_count_for_limit
      redirect_to @customer, alert: "Free plan limit reached: #{used}/#{User::FREE_QUOTE_LIMIT} company quotes used." and return
    end

    @quote = @customer.quotes.new(quote_params)
    @quote.company = current_user.company
    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.save
      redirect_to @quote
    else
      ensure_quote_item_row
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @document_kind = resolved_document_kind
  end

  def edit
    ensure_quote_item_row
  end

  def update
    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.update(quote_params)
      redirect_to @quote
    else
      ensure_quote_item_row
      render :edit, status: :unprocessable_entity
    end
  end

  def update_template
    template = current_user.company.quote_templates.find(params.require(:template_id))
    @quote.update!(template: template)
    @template = template
    @document_kind = resolved_document_kind

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "quote-page-content",
          partial: "quotes/show_content"
        )
      end
      format.json { render json: { message: "Template updated" } }
      format.html { redirect_to quote_path(@quote, doc: @document_kind), notice: "Template updated" }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { message: "Template not found" }, status: :not_found
  end

  def destroy
    @quote.destroy
    redirect_to @quote.customer
  end

  def export_pdf
    kind = resolved_document_kind
    pdf = quote_exporter(kind, @template).to_pdf

    send_data pdf.render,
              filename: "#{kind}_#{@quote.quote_no}.pdf",
              type: "application/pdf"
  end

  def export_xlsx
    kind = resolved_document_kind
    exporter = quote_exporter(kind, @template)
    package = exporter.to_xlsx
    payload = package.to_stream.read
    exporter.cleanup_tempfiles!

    send_data payload,
              filename: "#{kind}_#{@quote.quote_no}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  rescue StandardError
    exporter&.cleanup_tempfiles!
    raise
  end

  def duplicate
    @customer = @quote.customer
    @quote = @quote.build_revision
    ensure_quote_item_row
    flash.now[:notice] = "Revision draft created from quote #{@quote.quote_no}. Edit and save to create a new version."
    render :new, formats: :html
  end

  def share
    token = QuoteShare.generate_token
    snapshot = @quote.as_json
    snapshot["customer_name"] = @quote.customer.name
    snapshot["customer_contact_name"] = @quote.customer.contact_name
    snapshot["customer_address"] = @quote.customer.address
    snapshot["customer_phone"] = @quote.customer.phone
    snapshot["customer_email"] = @quote.customer.email
    snapshot["quote_items"] = @quote.quote_items.map { |item| build_quote_item_snapshot(item) }

    current_user.company.quote_shares.create!(quote: @quote, token: token, snapshot: snapshot)

    redirect_to public_quote_share_url(token, doc: resolved_document_kind)
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:customer_id])
  end

  def set_quote
    @quote = current_user.company.quotes.includes({ quote_items: :product }, :customer, :template).find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :quote_no,
      :currency,
      :issued_on,
      :valid_until,
      :payment_term,
      :status,
      :negotiated,
      :final_amount,
      :loss_reason,
      :notes,
      :tax_amount,
      :shipping_amount,
      :discount_amount,
      :terms_text,
      :legal_disclaimer,
      :delivery_notes,
      :template_id,
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity, :_destroy ]
    )
  end

  def set_form_products
    @products = current_user.company.products.order(:name)
  end

  def set_template_options
    @template_options = current_user.company.quote_templates.ordered
  end

  def ensure_quote_item_row
    return if @quote.quote_items.reject(&:marked_for_destruction?).any?

    @quote.quote_items.build
  end

  def quote_exporter(kind = "quote", template = nil)
    require Rails.root.join("app/services/quote_exporter").to_s unless defined?(::QuoteExporter)
    template ||= @template
    @quote_exporters ||= {}
    cache_key = "#{kind}-#{template&.id || 'default'}"
    @quote_exporters[cache_key] ||= ::QuoteExporter.new(@quote, template: template, document_kind: kind)
  end

  def set_template
    candidate = if params[:template_id].present?
      current_user.company.quote_templates.find_by(id: params[:template_id])
    else
      @quote.template
    end

    @template = candidate || current_user.company.quote_template_or_default
  end

  def resolved_document_kind
    @template.normalize_document_kind(params[:doc].presence || default_document_kind)
  end

  def default_document_kind
    @template.document_kind == "proforma_invoice" ? "pi" : "quote"
  end

  def build_quote_item_snapshot(item)
    snapshot = item.as_json
    snapshot["product_name"] = item.product&.name
    snapshot["product_image_path"] = if item.product&.image&.attached?
      Rails.application.routes.url_helpers.rails_blob_path(item.product.image, only_path: true)
    end
    snapshot
  end
end
