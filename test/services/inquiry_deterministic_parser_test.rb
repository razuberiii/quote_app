require "test_helper"

class InquiryDeterministicParserTest < ActiveSupport::TestCase
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
end
