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
    assert_select "main", text: /粘贴客户发来的内容/
    assert_select "main", text: /基础整理/, count: 0
  end

  test "customer requirement index resumes inquiry or its existing quote" do
    open_inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "chat", source_text: "",
      extracted_data: { "customer" => "Open Buyer" })
    converted = @user.company.inquiries.create!(created_by: @user, source_type: "chat", source_text: "",
      extracted_data: { "customer" => "Converted Buyer" }, status: "converted")
    customer = @user.company.customers.create!(name: "Converted Buyer")
    quote = @user.company.quotes.create!(customer:, inquiry: converted, currency: "USD", status: "draft",
      quote_items_attributes: [ { description: "Product", quantity: 1, unit_price: 10 } ])

    get inquiries_path

    assert_response :success
    assert_select ".inquiry-task-list a[href='#{inquiry_path(open_inquiry)}']", text: /继续准备报价/
    assert_select ".inquiry-task-list a[href='#{quote_path(quote)}']", text: /继续编辑报价/
  end

  test "one inquiry cannot create a second quote" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "chat", source_text: "")
    customer = @user.company.customers.create!(name: "Existing Buyer")
    quote = @user.company.quotes.create!(customer:, inquiry:, currency: "USD", status: "draft",
      quote_items_attributes: [ { description: "Product", quantity: 1, unit_price: 10 } ])

    assert_no_difference "Quote.count" do
      post build_quote_inquiry_path(inquiry)
    end
    assert_redirected_to quote_path(quote)
  end

  test "empty quote list recommends one focused first-quote action" do
    get quotes_path

    assert_response :success
    assert_select ".first-quote-launch", 1 do
      assert_select "a.button--primary[href='#{chat_integration_path}']", text: /连接聊天插件/
      assert_select "a.button--secondary[href='#{new_quote_path(manual: 1, anchor: "manual-options")}']", text: /其他开始方式/
    end
    assert_select ".quote-home__empty", 0
    assert_select ".quote-home__filters", 0
    assert_select ".quote-home__bar a.button", 0
    assert_select ".quote-home__list", 0
  end

  test "empty quote list keeps an imported customer request reachable" do
    @user.company.inquiries.create!(created_by: @user, source_type: "chat", source_text: "Please quote", status: "review")

    get quotes_path

    assert_response :success
    assert_select ".first-quote-launch a.button--primary[href='#{inquiries_path}']", text: /继续处理客户需求/
    assert_select ".first-quote-launch", text: /可以随时回来继续/
  end

  test "new quote separates the recommended intake from a collapsed manual form" do
    get new_quote_path

    assert_response :success
    assert_select ".first-quote-choice a.button--primary[href='#{chat_integration_path}']", 1
    assert_select "details.manual-quote-path:not([open])", 2
    assert_select "details.manual-quote-path a[href='#{new_inquiry_path}']", 1
    assert_select ".quote-start__choices", 0
    assert_select "main.quote-start a[href='#{library_path}']", 0
  end

  test "other start methods opens the paste fallback immediately" do
    get new_quote_path(manual: 1)

    assert_response :success
    assert_select "details#manual-options[open]", 1
    assert_select "details#manual-options a[href='#{new_inquiry_path}']", 1
  end

  test "focused inquiry intake keeps processing detail secondary" do
    get new_inquiry_path

    assert_response :success
    assert_select ".inquiry-import__composer textarea[autofocus]", 1
    assert_select ".inquiry-import__rail--focused input[type='submit'][value='准备报价草稿']", 1
    assert_select "details.inquiry-import__details:not([open])", 1
    assert_select ".inquiry-import__steps", 0
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

  test "saving a quote returns to the workspace with automatic save confirmation" do
    customer = @user.company.customers.create!(name: "Save Feedback Buyer")
    quote = @user.company.quotes.new(customer:, currency: "USD", status: "draft", issued_on: Date.current)
    quote.quote_items.build(description: "Model A cart", quantity: 12, unit_price: 500)
    quote.save!

    patch quote_path(quote), params: { quote: { currency: "USD", notes: "Updated draft" } }

    assert_redirected_to quote_path(quote, saved: 1)
    follow_redirect!
    assert_response :success
    assert_select ".studio-save-state.is-saved", text: /已自动保存/
  end

  test "a manually added unpriced product can be saved as a draft" do
    customer = @user.company.customers.create!(name: "Manual Product Buyer")
    quote = @user.company.quotes.create!(customer:, currency: "USD", status: "draft", issued_on: Date.current,
      quote_items_attributes: [ { description: "Existing item", quantity: 1, unit_price: 100 } ])

    assert_difference -> { quote.quote_items.count }, 1 do
      patch quote_path(quote), params: { quote: { quote_items_attributes: {
        "0" => { id: quote.quote_items.first.id, description: "Existing item", quantity: 1, unit_price: 100 },
        "999999" => { description: "Manual spare part", quantity: 1, unit_price: 0,
          price_source: "unpriced", selection_mode: "fixed" }
      } } }
    end

    assert_redirected_to quote_path(quote, saved: 1)
    added = quote.reload.quote_items.find_by!(description: "Manual spare part")
    assert_equal 0.to_d, added.unit_price
    assert_equal "unpriced", added.price_source
  end

  test "customer preview includes the unified publish action" do
    customer = @user.company.customers.create!(name: "Preview Buyer")
    quote = @user.company.quotes.create!(customer:, currency: "USD", status: "draft", issued_on: Date.current,
      valid_until: 30.days.from_now.to_date, payment_term: "30% deposit", trade_term: "EXW",
      quote_items_attributes: [ { description: "Ready item", quantity: 1, unit_price: 100, price_source: "manual" } ])

    get preview_quote_path(quote)

    assert_response :success
    assert_select ".seller-preview-bar form", 1 do
      assert_select "button", text: /发布并复制链接/
    end
    assert_select ".seller-preview-bar a[href='#{quote_path(quote)}']", text: /返回编辑/
  end

  test "quote workspace exposes one context-aware preview action" do
    customer = @user.company.customers.create!(name: "Preview Action Buyer")
    quote = @user.company.quotes.create!(customer:, currency: "USD", status: "draft", issued_on: Date.current,
      quote_items_attributes: [ { description: "Pending item", quantity: 1, unit_price: 0 } ])

    get quote_path(quote)

    assert_response :success
    assert_select ".studio-actions a[href='#{preview_quote_path(quote)}']", 1
  end

  test "publication success preview renders the immutable published revision" do
    customer = @user.company.customers.create!(name: "Published Buyer")
    quote = @user.company.quotes.create!(customer:, currency: "USD", status: "draft", issued_on: Date.current,
      valid_until: 30.days.from_now.to_date, payment_term: "30% deposit", trade_term: "EXW",
      quote_items_attributes: [ { description: "Ready item", quantity: 1, unit_price: 100, price_source: "manual" } ])
    result = RevisionPublisher.new(quote:, actor: @user, url_options: { host: "www.example.com", protocol: "http" }).call

    get preview_quote_path(quote, published_revision_id: result.revision.id)

    assert_response :success
    assert_select ".seller-preview-bar", text: /V1 已锁定/
    assert_select ".buyer-header__trust", text: /Revision 1/
    assert_select ".quote-meta > div:nth-child(2) dd", text: "1"
    assert_select ".state-banner", 0
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

  test "draft keeps payment delivery and packing extracted from the customer request" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "chat", source_text: <<~TEXT)
      客户（Ana / Pacific Foods）：需要 2 台自动装箱机，型号 ACM-9000，请报 FOB Shenzhen，期望 30 天内交付。
      客户：使用出口木箱。付款希望 30% 定金，70% 发货前。邮箱 ana@pacific.example。
    TEXT
    inquiry.manually_extract!
    inquiry.update!(extracted_data: inquiry.extracted_data.merge("currency" => "USD"))

    post build_quote_inquiry_path(inquiry)

    quote = inquiry.reload.quote
    assert_equal "30% 定金，70% 发货前", quote.payment_term
    assert_equal "30 天内交付", quote.delivery_notes
    assert_equal "30 天内交付", quote.quote_items.first.lead_time_snapshot
    assert_equal "出口木箱", quote.quote_items.first.packing_snapshot
  end

  test "review exposes a manual Deal-only product action" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "email", source_text: "Custom assembly requested")
    inquiry.manually_extract!
    get inquiry_path(inquiry)
    assert_response :success
    assert_select "[data-action='inquiry-review#addProduct']", text: /#{Regexp.escape(I18n.t("self_service.review.add_manual_product"))}/
  end

  test "unpriced draft keeps the create action at the review footer only" do
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "chat", status: "review",
      extracted_data: { "customer" => "Atlas Machinery", "currency" => "USD",
        "products" => [ { "name" => "Hydraulic Power Unit", "quantity" => 5 } ], "commercial_terms" => {} })

    get inquiry_path(inquiry)

    assert_response :success
    assert_select ".draft-preparation__actions button[name='build_deal']", 0
    assert_select ".inquiry-review__actions button[name='build_deal']", 1
  end

  test "review prepares a safe catalog recommendation and keeps all extracted specifications editable" do
    product = @user.company.products.create!(name: "Hydraulic Power Unit", sku: "HPU-380", default_price: 725,
      price_currency: "USD", unit: "set", lead_time: "18 days",
      default_specs: [ { name: "Voltage", value: "380V" }, { name: "Protection", value: "IP54" } ])
    inquiry = @user.company.inquiries.create!(created_by: @user, source_type: "chat", status: "review",
      extracted_data: { "customer" => "Atlas Machinery", "currency" => "USD",
        "products" => [ { "name" => "Hydraulic Power Unit", "model" => "HPU-380", "quantity" => 5,
          "unit" => "set", "specifications" => { "Voltage" => "380V", "Frequency" => "50Hz" } } ],
        "commercial_terms" => {} })

    get inquiry_path(inquiry)

    assert_response :success
    assert_select ".draft-preparation", text: /推荐草稿/
    assert_select ".draft-preparation__actions button[form='inquiry-review-form'][name='build_deal']", text: /创建报价草稿/
    assert_select ".draft-preparation__actions a[href='#quote-products']", text: /确认产品方案/
    assert_select "details.review-guidance--compact:not([open])", 1
    assert_select "details.inquiry-evidence-drawer:not([open])", 1
    assert_select "input[name='inquiry[extracted_data][products][0][catalog_product_id]'][value='#{product.id}'][checked]"
    assert_select "input[name='inquiry[extracted_data][products][0][unit_price]'][value='725.0']"
    assert_select "input[data-spec-key='Frequency'][value='50Hz']"
    assert_select "input[data-spec-key='Protection'][value='IP54']"
    assert_select "input[data-action='change->inquiry-review#applyCandidate']", minimum: 1
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
