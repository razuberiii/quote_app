class QuotesController < ApplicationController
  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate share]
  before_action :set_form_products, only: %i[new edit create update duplicate]

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.latest_versions
    redirect_to @customer
  end

  def new
    @quote = @customer.quotes.new(currency: "USD", status: "pending")
    ensure_quote_item_row
  end

  def create
    @quote = @customer.quotes.new(quote_params)
    @quote.company = current_user.company

    if @quote.save
      redirect_to @quote
    else
      ensure_quote_item_row
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    ensure_quote_item_row
  end

  def update
    if @quote.update(quote_params)
      redirect_to @quote
    else
      ensure_quote_item_row
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quote.destroy
    redirect_to @quote.customer
  end

  def export_pdf
    pdf = quote_exporter.to_pdf

    send_data pdf.render,
              filename: "quote_#{@quote.quote_no}.pdf",
              type: "application/pdf"
  end

  def export_xlsx
    exporter = quote_exporter
    package = exporter.to_xlsx
    payload = package.to_stream.read
    exporter.cleanup_tempfiles!

    send_data payload,
              filename: "quote_#{@quote.quote_no}.xlsx",
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

    redirect_to public_quote_share_url(token)
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:customer_id])
  end

  def set_quote
    @quote = current_user.company.quotes.includes({ quote_items: :product }, :customer).find(params[:id])
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
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity, :_destroy ]
    )
  end

  def set_form_products
    @products = current_user.company.products.order(:name)
  end

  def ensure_quote_item_row
    return if @quote.quote_items.reject(&:marked_for_destruction?).any?

    @quote.quote_items.build
  end

  def quote_exporter
    require Rails.root.join("app/services/quote_exporter").to_s unless defined?(::QuoteExporter)
    @quote_exporter ||= ::QuoteExporter.new(@quote, template: current_user.company.quote_template_or_default)
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
