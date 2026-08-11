require "test_helper"

class InquiryAiContextBuilderTest < ActiveSupport::TestCase
  test "keeps task facts and recent messages within a fixed character budget" do
    inquiry = companies(:one).inquiries.create!(source_type: "chat", status: "review",
      extracted_data: { "customer" => "North Harbor", "currency" => "USD" })
    30.times do |index|
      inquiry.inquiry_messages.create!(direction: index.even? ? "buyer" : "seller", channel: "whatsapp",
        occurred_at: index.minutes.ago, body: "message #{index} #{"x" * 180}")
    end

    context = InquiryAiContextBuilder.new(inquiry, max_characters: 2_400).call
    assert_operator context.length, :<=, 2_400
    assert_includes context, "North Harbor"
    assert_includes context, "earlier messages omitted"
    assert_includes context, "message 29"
  end
end
