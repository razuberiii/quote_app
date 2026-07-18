require "test_helper"

class InquiryGuidanceTest < ActiveSupport::TestCase
  test "only buyer currency product and quantity block the working draft" do
    inquiry = Inquiry.new(extracted_data: {
      "customer" => "Atlas Machinery LLC", "currency" => "USD",
      "products" => [ { "name" => "Hydraulic power unit", "quantity" => 12 } ],
      "commercial_terms" => { "incoterm" => "CIF" }
    })
    guidance = InquiryGuidance.new(inquiry)

    assert_nil guidance.next_item
    assert guidance.items.find { |item| item.label.include?("单价") }.complete == false
    assert guidance.items.find { |item| item.label.include?("运费") }.complete == false
    assert_equal :optional, guidance.items.last.level
  end

  test "identifies one clear next action instead of a wall of missing fields" do
    guidance = InquiryGuidance.new(Inquiry.new(extracted_data: { "products" => [] }))
    assert_equal "确认买家公司", guidance.next_item.label
    assert_equal :now, guidance.next_item.level
  end
end
