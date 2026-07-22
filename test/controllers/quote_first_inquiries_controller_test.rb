require "test_helper"

class QuoteFirstInquiriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    company = Company.create!(name: "First Quote Factory", default_currency: "USD")
    @user = User.create!(company: company, company_role: :owner, username: "first_quote_user",
      email: "first-quote@example.com", password: "password123", email_verified_at: Time.current)
    sign_in @user
  end

  test "new quote has one customer-message intake path" do
    get new_inquiry_path

    assert_response :success
    assert_select "input[type='hidden'][name='inquiry[source_type]'][value='email']", 1
    assert_select ".inquiry-import__source-tabs--mode", 0
    assert_select "main", text: /从客户消息开始/
    assert_select "main", text: /基础整理/, count: 0
  end

  test "initial AI analysis is queued without blocking the create request" do
    assert_enqueued_with(job: InitialInquiryAnalysisJob) do
      post inquiries_path, params: { inquiry: { source_type: "email", source_text: "Please quote 12 model A carts at USD 500." } }
    end

    inquiry = @user.company.inquiries.order(:id).last
    assert_redirected_to inquiry_path(inquiry)
    assert_equal "processing", inquiry.status

    get inquiry_path(inquiry)
    assert_response :success
    assert_select "[data-controller='catalog-processing']"

    get inquiry_path(inquiry, format: :json)
    assert_equal "processing", response.parsed_body["status"]
  end

  test "saving a quote returns to Studio with a rendered save time" do
    customer = @user.company.customers.create!(name: "Save Feedback Buyer")
    quote = @user.company.quotes.new(customer:, currency: "USD", status: "draft", issued_on: Date.current)
    quote.quote_items.build(description: "Model A cart", quantity: 12, unit_price: 500)
    quote.save!

    patch quote_path(quote), params: { quote: { currency: "USD", notes: "Updated draft" } }

    assert_redirected_to edit_quote_path(quote, saved: 1)
    follow_redirect!
    assert_response :success
    assert_select ".studio-save-state.is-saved", text: /已保存 · \d{2}:\d{2}/
  end

  test "empty Library does not block a multi item Working draft" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "email", source_text: <<~TEXT)
      Please quote CIF Jebel Ali for:
      1. 12 hydraulic power units model HPU-380, 380V/50Hz.
      2. 30 stainless dosing pumps model GDP-40, 220V/50Hz.
      Regards, Omar, Atlas Machinery LLC, purchasing@atlas.example
    TEXT
    inquiry.manually_extract!
    inquiry.update!(extracted_data: inquiry.extracted_data.merge("currency" => "USD"))

    assert_difference -> { Quote.count }, 1 do
      assert_no_difference -> { Product.count } do
        post build_quote_inquiry_path(inquiry)
      end
    end
    quote = Quote.order(:id).last
    assert_redirected_to edit_quote_path(quote)
    assert_equal 2, quote.quote_items.size
    assert quote.quote_items.all? { |item| item.product_id.nil? && item.price_source == "unpriced" }
    assert_equal 0, @user.company.products.count
  end

  test "review exposes a manual Deal-only product action" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "email", source_text: "Custom assembly requested")
    inquiry.manually_extract!
    get inquiry_path(inquiry)
    assert_response :success
    assert_select "[data-action='inquiry-review#addProduct']", text: /#{Regexp.escape(I18n.t("self_service.review.add_manual_product"))}/
  end

  test "primary Build Deal action saves the current review before creating" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "manual", source_text: "Custom assembly")
    inquiry.manually_extract!
    patch inquiry_path(inquiry), params: { build_deal: "1", inquiry: { extracted_data: {
      customer: "New Buyer Ltd", currency: "USD",
      products: { "0" => { name: "Deal-only control cabinet", quantity: "4", unit: "sets", unit_price: "2400", price_source: "manual" } },
      commercial_terms: { incoterm: "CIF", freight_amount: "1800", freight_source: "freight_forwarder_quote" }, questions: "", missing_information: ""
    } } }

    quote = inquiry.reload.quote
    assert_redirected_to edit_quote_path(quote)
    assert_equal "New Buyer Ltd", quote.customer.name
    assert_equal "Deal-only control cabinet", quote.quote_items.first.description
    assert_equal 4, quote.quote_items.first.quantity
    assert_equal 2400.to_d, quote.quote_items.first.unit_price
    assert_equal "manual", quote.quote_items.first.price_source
    assert_equal 1800.to_d, quote.shipping_amount
    assert_equal "freight_forwarder_quote", quote.shipping_price_source
  end
end
