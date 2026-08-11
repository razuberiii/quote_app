require "test_helper"

class QuoteCoreResourcesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "document design replaces template management" do
    get edit_document_design_path
    assert_response :success
    assert_select ".document-design"
    assert_select ".design-paper"

    get quote_templates_path
    assert_redirected_to edit_document_design_path
  end

  test "AI import hub exposes imports and chat synchronization" do
    get imports_path
    assert_response :success
    assert_select ".import-hub__row", 5
  end

  test "chat integration lists a return path to bound inquiries" do
    inquiry = companies(:one).inquiries.create!(created_by: users(:one), source_type: "chat", source_text: "")
    companies(:one).chat_conversation_bindings.create!(user: users(:one), inquiry:, platform: "alibaba",
      platform_account_id: "seller-1", platform_conversation_id: "thread-42", display_name: "Atlas Buyer")

    get chat_integration_path

    assert_response :success
    assert_select ".chat-sync-conversations a[href='#{inquiry_path(inquiry)}']", text: /查看询盘|Review request/
    assert_select ".chat-sync-conversations", text: /Atlas Buyer/
    assert_select "[data-chat-pairing-target='copy']", 1
    assert_select "[data-chat-pairing-target='countdown']", 1
  end

  test "customer resource renders without CRM dashboard" do
    get customers_path
    assert_response :success
    assert_select ".customer-core"
    assert_select ".dashboard-module", 0
  end

  test "new quote recommends chat sync with manual fallbacks" do
    get new_quote_path

    assert_response :success
    assert_select ".quote-start"
    assert_select "form[action='#{quotes_path}']"
    assert_select "a.button--primary[href='#{chat_integration_path}']"
    assert_select "a[href='#{new_inquiry_path}']"
  end

  test "blank quote starts from an existing customer and opens the workspace" do
    customer = customers(:one)

    assert_difference "Quote.count", 1 do
      post quotes_path, params: { blank_quote: { customer_id: customer.id } }
    end

    quote = Quote.order(:created_at).last
    assert_redirected_to quote_path(quote)
    assert_equal customer, quote.customer
    assert_equal "unpriced", quote.quote_items.first.price_source
    assert_equal 0.to_d, quote.quote_items.first.unit_price
  end

  test "blank quote can create its customer without AI intake" do
    assert_difference [ "Customer.count", "Quote.count" ], 1 do
      post quotes_path, params: { blank_quote: {
        customer_name: "Northstar Components",
        contact_name: "Mina Patel",
        customer_email: "mina@northstar.example"
      } }
    end

    quote = Quote.order(:created_at).last
    assert_redirected_to quote_path(quote)
    assert_equal "Northstar Components", quote.customer.name
    assert_equal "Mina Patel", quote.customer.contact_name

    get quote_path(quote)
    assert_response :success
    assert_select ".studio-readiness a[href='#studio-terms']", minimum: 2
    assert_select ".studio-readiness a[href='#studio-products']", minimum: 2
    assert_select ".studio-readiness a[href='#studio-pricing']", minimum: 1
  end

  test "blank quote keeps validation on the creation page" do
    assert_no_difference [ "Customer.count", "Quote.count" ] do
      post quotes_path, params: { blank_quote: { customer_name: "" } }
    end

    assert_response :unprocessable_entity
    assert_select ".quote-start__errors"
  end

  test "published versions expose direct PDF and Excel downloads" do
    revision = quotes(:one).quote_revisions.create!(company: companies(:one), number: 1, status: "current",
      currency: "USD", total: 100, snapshot: QuoteSnapshotBuilder.new(quotes(:one)).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    get quote_path(quotes(:one), tab: "versions")
    assert_response :success
    assert_select "a[href='#{quote_version_export_path(quotes(:one), revision, output: 'pdf')}']"
    assert_select "a[href='#{quote_version_export_path(quotes(:one), revision, output: 'excel')}']"
  end

  test "buyer page renders frozen base-template custom fields" do
    quote = quotes(:one)
    design = quote.company.quote_template_or_default
    design.update!(custom_fields: [ { "key" => "certificate", "label" => "Certificate requirement", "required" => false, "type" => "text" } ])
    quote.update!(template: design, custom_field_values: { "certificate" => "CE and RoHS" })
    revision = quote.quote_revisions.create!(company: companies(:one), number: 1, status: "current",
      currency: "USD", total: quote.grand_total, snapshot: QuoteSnapshotBuilder.new(quote).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    get buyer_room_path(revision.secure_token)

    assert_response :success
    assert_select ".buyer-commercial", text: /Certificate requirement/
    assert_select ".buyer-commercial", text: /CE and RoHS/
  end

  test "buyer quantity changes become a reviewed revision draft without mutating the published version" do
    quote = quotes(:one)
    revision = quote.quote_revisions.create!(company: companies(:one), number: 1, status: "current",
      currency: "USD", total: quote.grand_total, snapshot: QuoteSnapshotBuilder.new(quote).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)
    request_record = revision.change_requests.create!(company: companies(:one), message: "Please increase quantity",
      idempotency_key: SecureRandom.uuid, requested_changes: { "quantities" => { "0" => "8" } })

    patch apply_change_request_quote_path(quote, change_request_id: request_record.id)

    assert_redirected_to edit_quote_path(quote, source_version: 1)
    assert_equal 8, quote.quote_items.first.reload.quantity
    assert_equal "reviewed", request_record.reload.status
    assert_equal 5, revision.reload.snapshot.fetch("quote_items").first.fetch("quantity")
  end
end
