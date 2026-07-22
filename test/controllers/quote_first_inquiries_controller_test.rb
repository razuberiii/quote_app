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
      products: { "0" => { name: "Deal-only control cabinet", quantity: "4", unit: "sets", price_source: "unpriced" } },
      commercial_terms: { incoterm: "EXW" }, questions: "", missing_information: ""
    } } }

    quote = inquiry.reload.quote
    assert_redirected_to edit_quote_path(quote)
    assert_equal "New Buyer Ltd", quote.customer.name
    assert_equal "Deal-only control cabinet", quote.quote_items.first.description
    assert_equal 4, quote.quote_items.first.quantity
  end
end
