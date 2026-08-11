require "test_helper"

class InquiryQuoteDraftPreparerTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    @inquiry = @company.inquiries.create!(created_by: users(:one), source_type: "chat", status: "review",
      extracted_data: {
        "customer" => "Atlas Industrial", "currency" => "USD",
        "products" => [ { "name" => "Hydraulic Pump", "model" => "HZ-240", "quantity" => 5,
          "unit" => "sets", "specifications" => { "Voltage" => "380V" } } ],
        "commercial_terms" => {}
      })
    products(:one).update!(price_currency: "USD", default_price: 480, unit: "set", moq: 2,
      lead_time: "20 days", default_specs: [ { name: "Voltage", value: "380V" } ])
  end

  test "prepares an explainable catalog-backed recommendation" do
    result = InquiryQuoteDraftPreparer.new(@inquiry).call
    candidate = result[:items].first[:recommended]

    assert_equal products(:one), candidate[:product]
    assert candidate[:recommended]
    assert candidate[:price_available]
    assert_equal "480.0", candidate.dig(:proposal, :unit_price)
    assert_equal "catalog", candidate.dig(:proposal, :price_source)
    assert_equal "380V", candidate.dig(:proposal, :specifications, "Voltage")
    assert_equal 1, result[:priced_count]
  end

  test "does not propose a catalog price in a different currency" do
    products(:one).update!(price_currency: "EUR")

    candidate = InquiryQuoteDraftPreparer.new(@inquiry).call[:items].first[:recommended]

    assert_not candidate[:price_available]
    assert_nil candidate.dig(:proposal, :unit_price)
    assert_equal "unpriced", candidate.dig(:proposal, :price_source)
    assert_includes candidate[:warnings], "currency_mismatch"
  end

  test "surfaces MOQ and specification conflicts" do
    @inquiry.update!(extracted_data: @inquiry.extracted_data.deep_merge(
      "products" => [ { "name" => "Hydraulic Pump", "model" => "HZ-240", "quantity" => 1,
        "specifications" => { "Voltage" => "220V" } } ]))

    candidate = InquiryQuoteDraftPreparer.new(@inquiry).call[:items].first[:recommended]

    assert_includes candidate[:warnings], "below_moq"
    assert_includes candidate[:warnings], "specification_conflict"
    assert_not candidate[:recommended]
  end
end
