class InquiriesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_inquiry, only: %i[show update build_quote]

  def index
    @inquiries = current_user.company.inquiries.order(created_at: :desc)
  end

  def new
    @inquiry = current_user.company.inquiries.new
  end

  def create
    @inquiry = current_user.company.inquiries.new(inquiry_params.merge(created_by: current_user))
    @inquiry.save!
    @inquiry.source_file.attach(params.dig(:inquiry, :source_file)) if params.dig(:inquiry, :source_file).present?
    if @inquiry.source_text.blank? && @inquiry.source_file.attached?
      @inquiry.update!(source_text: InquirySourceReader.new(@inquiry.source_file).call, source_type: inferred_source_type)
    end
    @inquiry.extract_requirements!
    redirect_to @inquiry, notice: t("self_service.intake.extracted")
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError, InquirySourceReader::UnsupportedFile, InquirySourceReader::UnreadableFile => error
    @inquiry&.manually_extract!
    Rails.logger.warn("Inquiry AI extraction failed: #{error.class}: #{error.message}")
    redirect_to @inquiry, alert: t("self_service.intake.fallback")
  end

  def show
    @catalog_matches = @inquiry.catalog_matches
    @catalog_products = current_user.company.products.order(:name)
    @guidance = InquiryGuidance.new(@inquiry)
  end

  def update
    data = reviewed_data
    @inquiry.update!(inquiry_params.except(:extracted_data).merge(extracted_data: data, field_states: reviewed_states(data)))
    return build_quote if params[:build_deal].present?
    redirect_to @inquiry, notice: t("self_service.intake.review_saved")
  end

  def build_quote
    if params[:inquiry].present? && @inquiry.extracted_data.blank?
      data = reviewed_data
      @inquiry.update!(inquiry_params.except(:extracted_data).merge(extracted_data: data, field_states: reviewed_states(data)))
    end
    unless @inquiry.ready_to_build_quote?
      redirect_to @inquiry, alert: t("self_service.intake.build_blocked")
      return
    end
    data = @inquiry.extracted_data
    customer = @inquiry.customer || current_user.company.customers.create!(
      name: data["customer"], contact_name: data["contact_name"], email: data["contact_email"], country: data["country"],
      notes: "Created from inquiry ##{@inquiry.id}"
    )
    quote = current_user.company.quotes.new(customer: customer, currency: @inquiry.extracted_data["currency"].presence || current_user.company.default_currency,
      inquiry: @inquiry, issued_on: Date.current, valid_until: 30.days.from_now, status: "draft", custom_title: "Proposal for #{customer.name}",
      trade_term: data.dig("commercial_terms", "incoterm"), delivery_notes: data.dig("commercial_terms", "delivery"),
      shipping_amount: data.dig("commercial_terms", "freight_amount"), shipping_price_source: data.dig("commercial_terms", "freight_source"),
      internal_note: "Source inquiry ##{@inquiry.id}. AI extraction and user corrections retained on inquiry record.")
    Array(data["products"]).each do |item|
      product = current_user.company.products.find_by(id: item["catalog_product_id"])
      specs = item.fetch("specifications", {}).filter_map { |key, value| { key: key.humanize, value: value } if value.present? }
      quote.quote_items.build(product: product, description: item["name"], quantity: item["quantity"].to_i, unit_price: item["unit_price"].to_d,
        specifications: specs, price_source: item["price_source"].presence || "unpriced", selection_mode: item["selection_mode"].presence || "fixed",
        sku_snapshot: product&.sku || item["model"], unit_snapshot: item["unit"], lead_time_snapshot: item["lead_time"], packing_snapshot: item["packing"])
    end
    quote.save!
    @inquiry.update!(status: "converted", customer: customer)
    redirect_to edit_quote_path(quote), notice: t("self_service.intake.deal_created", count: quote.quote_items.count)
  end

  private

  def load_inquiry
    @inquiry = current_user.company.inquiries.find(params[:id])
  end

  def inquiry_params
    params.require(:inquiry).permit(:source_text, :source_type, :source_file, :customer_id, extracted_data: {}, field_states: {})
  end

  def reviewed_data
    raw = params.require(:inquiry).fetch(:extracted_data, {}).to_unsafe_h.deep_stringify_keys
    raw["products"] = raw.fetch("products", {}).values if raw["products"].is_a?(Hash)
    raw["questions"] = raw["questions"].to_s.lines.map(&:strip).reject(&:blank?)
    raw["missing_information"] = raw["missing_information"].to_s.lines.map(&:strip).reject(&:blank?)
    raw
  end

  def reviewed_states(data)
    { "customer" => data["customer"].present? ? "confirmed" : "missing", "products" => Array(data["products"]).any? ? "matched" : "missing",
      "price" => Array(data["products"]).all? { |item| item["unit_price"].to_d.positive? } ? "confirmed" : "missing",
      "freight" => data.dig("commercial_terms", "freight_amount").to_d.positive? && data.dig("commercial_terms", "freight_source").present? ? "confirmed" : "missing" }
  end

  def inferred_source_type
    @inquiry.source_file.content_type == "application/pdf" ? "pdf" : "excel"
  end
end
