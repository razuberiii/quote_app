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
    @inquiry.extract_requirements!
    redirect_to @inquiry, notice: "Inquiry extracted. Confirm every field before building the quotation."
  rescue InquiryAiExtractor::ConfigurationError, InquiryAiExtractor::ResponseError => error
    @inquiry&.manually_extract!
    Rails.logger.warn("Inquiry AI extraction failed: #{error.class}: #{error.message}")
    redirect_to @inquiry, alert: "AI extraction is temporarily unavailable. The inquiry was saved for manual review."
  end

  def show; end

  def update
    @inquiry.update!(inquiry_params)
    redirect_to @inquiry, notice: "Inquiry review saved."
  end

  def build_quote
    customer = @inquiry.customer || current_user.company.customers.create!(name: @inquiry.extracted_data["customer"].presence || "New buyer")
    quote = current_user.company.quotes.new(customer: customer, currency: @inquiry.extracted_data["currency"].presence || current_user.company.default_currency,
      issued_on: Date.current, valid_until: 30.days.from_now, status: "draft", custom_title: "Export quotation")
    quote.quote_items.build(description: "Product — confirmation required", quantity: 1, unit_price: 0)
    quote.save!
    redirect_to edit_quote_path(quote), notice: "Draft built. Confirm every price and freight amount before sending."
  end

  private

  def load_inquiry
    @inquiry = current_user.company.inquiries.find(params[:id])
  end

  def inquiry_params
    params.require(:inquiry).permit(:source_text, :source_type, :customer_id, extracted_data: {}, field_states: {})
  end
end
