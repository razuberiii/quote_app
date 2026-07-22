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
end
