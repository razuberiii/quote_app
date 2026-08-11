require "test_helper"

class InquiryDeterministicParserTest < ActiveSupport::TestCase
  test "extracts an unnumbered follow-up containing quantity and model" do
    result = InquiryDeterministicParser.new("We need 6 sets, model HPU-380 or equivalent, 380V/50Hz.").call
    assert_equal "HPU-380", result.dig("products", 0, "model")
    assert_equal 6, result.dig("products", 0, "quantity")
    assert_equal "380V/50Hz", result.dig("products", 0, "specifications", "voltage")
  end

  test "ignores conversation metadata after a signature" do
    result = InquiryDeterministicParser.new("Regards,\nDaniel Wu\nNorth Harbor Engineering\n\n[2026-07-22 · buyer · email]\nCIF Rotterdam in USD").call
    assert_equal "North Harbor Engineering", result["customer"]
    assert_equal "Rotterdam", result["destination"]
  end

  test "extracts contact and company from a multiline signature" do
    result = InquiryDeterministicParser.new("Please quote.\n\nRegards,\nDaniel Wu\nNorth Harbor Engineering").call
    assert_equal "Daniel Wu", result["contact_name"]
    assert_equal "North Harbor Engineering", result["customer"]
  end

  SOURCE = <<~TEXT
    Dear Sales,
    Please quote CIF Jebel Ali for:
    1. 12 hydraulic power units model HPU-380, 380V/50Hz, blue.
    2. 30 stainless gear dosing pumps model GDP-40, 220V/50Hz.
    Regards, Omar, Atlas Machinery LLC, purchasing@atlas.example
  TEXT

  test "keeps a multi product inquiry usable when AI is unavailable" do
    data = InquiryDeterministicParser.new(SOURCE).call
    assert_equal "Atlas Machinery LLC", data["customer"]
    assert_equal "Omar", data["contact_name"]
    assert_equal "purchasing@atlas.example", data["contact_email"]
    assert_equal "CIF", data["incoterm"]
    assert_equal "Jebel Ali", data["destination"]
    assert_equal 2, data["products"].size
    assert_equal "HPU-380", data.dig("products", 0, "model")
    assert_equal 12.0, data.dig("products", 0, "quantity")
    assert_equal "380V/50Hz", data.dig("products", 0, "specifications", "voltage")
    assert_nil data.dig("products", 0, "unit_price")
  end

  test "manual review stores deterministic candidates instead of an empty form" do
    inquiry = companies(:one).inquiries.create!(source_type: "email", source_text: SOURCE)
    inquiry.manually_extract!
    assert_equal 2, inquiry.extracted_data["products"].size
    assert_equal "review", inquiry.status
    assert_equal "uncertain", inquiry.field_states["products"]
  end

  test "manual chat fallback preserves its explicitly bound customer" do
    inquiry = companies(:one).inquiries.create!(source_type: "chat", source_text: "We need 6 sets, model HPU-380.", customer: customers(:one),
      extracted_data: { "task_context" => { "reason" => "new_messages_after_closed_quote" } })
    inquiry.manually_extract!

    assert_equal customers(:one).name, inquiry.extracted_data["customer"]
    assert_equal "new_messages_after_closed_quote", inquiry.extracted_data.dig("task_context", "reason")
  end

  test "extracts buyer identity and product from a Chinese chat transcript" do
    source = <<~TEXT
      客户（Maria / Andes Foods）：你好，我们需要 3 台自动装箱机，型号 ACM-9000。电源 380V 50Hz，需要视觉检测和不锈钢机架，请报 CIF Callao，期望 35 天内交付。
      销售（我）：收到，请问目标预算、包装和付款条件？
      客户：预算每台不超过 USD 20,000，出口木箱。付款希望 30% 定金，70% 发货前。邮箱 maria@andes-foods.example。
    TEXT

    data = InquiryDeterministicParser.new(source).call
    assert_equal "Andes Foods", data["customer"]
    assert_equal "Maria", data["contact_name"]
    assert_equal "maria@andes-foods.example", data["contact_email"]
    assert_equal "USD", data["currency"]
    assert_equal "CIF", data["incoterm"]
    assert_equal "Callao", data["destination"]
    assert_equal "35 天内交付", data["delivery"]
    assert_equal "出口木箱", data["packing"]
    assert_equal "30% 定金，70% 发货前", data["payment_terms"]
    assert_equal "自动装箱机", data.dig("products", 0, "name")
    assert_equal "ACM-9000", data.dig("products", 0, "model")
    assert_equal 3, data.dig("products", 0, "quantity")
    assert_equal "台", data.dig("products", 0, "unit")
    assert_equal "380V 50Hz", data.dig("products", 0, "specifications", "voltage")
    assert_equal "视觉检测和不锈钢机架", data.dig("products", 0, "specifications", "配置要求")
  end


  test "extracts normalized Alibaba conversation messages" do
    source = <<~TEXT
      [message_id=ali-msg-1 | role=customer | type=text | channel=other | sent_at=2026-08-06T04:00:00Z | sender=Carlos]
      Hello, we need 4 sets automatic labeling machine, model ALM-600. Power 220V 60Hz. Please include stainless steel body and date-code printer. Quote CIF Lima, delivery within 25 days.

      [message_id=ali-msg-3 | role=customer | type=text | channel=other | sent_at=2026-08-06T04:02:00Z | sender=Carlos]
      Budget is below USD 8,500 per set. Export plywood case. Payment 30% deposit, 70% before shipment. Email carlos@andes-retail.example
    TEXT

    data = InquiryDeterministicParser.new(source).call
    assert_equal "Carlos", data["contact_name"]
    assert_equal "automatic labeling machine", data.dig("products", 0, "name")
    assert_equal "ALM-600", data.dig("products", 0, "model")
    assert_equal "stainless steel body and date-code printer", data.dig("products", 0, "specifications", "配置要求")
    assert_equal "25 days delivery", data["delivery"]
    assert_equal "Export plywood case", data["packing"]
    assert_equal "30% deposit, 70% before shipment", data["payment_terms"]
  end

  test "AI reconciliation keeps bound identity and deterministic commercial facts" do
    inquiry = companies(:one).inquiries.new(customer: customers(:one), source_type: "chat")
    ai_data = { "customer" => "70% before shipment. Email", "contact_name" => "Budget is below USD 8",
      "contact_email" => nil, "currency" => "USD", "commercial_terms" => { "incoterm" => "CIF" },
      "products" => [ { "name" => "ALM-600.", "model" => "ALM-600", "specifications" => {} } ] }
    deterministic = { "contact_name" => "Carlos", "contact_email" => "carlos@example.com", "currency" => "USD",
      "destination" => "Lima", "packing" => "Export plywood case", "payment_terms" => "30% deposit, 70% before shipment",
      "products" => [ { "name" => "automatic labeling machine", "model" => "ALM-600", "quantity" => 4,
        "unit" => "sets", "specifications" => { "voltage" => "220V 60Hz" } } ] }

    result = InquiryAiExtractor.new(inquiry: inquiry).send(:reconcile, ai_data, deterministic, inquiry)
    assert_equal customers(:one).name, result["customer"]
    assert_equal "Carlos", result["contact_name"]
    assert_equal "Lima", result.dig("commercial_terms", "destination")
    assert_equal "automatic labeling machine", result.dig("products", 0, "name")
    assert_equal "220V 60Hz", result.dig("products", 0, "specifications", "voltage")
  end
end
