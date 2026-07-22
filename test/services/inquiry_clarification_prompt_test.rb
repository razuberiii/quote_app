require "test_helper"

class InquiryClarificationPromptTest < ActiveSupport::TestCase
  test "asks only for missing quote inputs" do
    inquiry = Inquiry.new(extracted_data: { "customer" => "Atlas", "currency" => "USD", "products" => [ { "name" => "Pump" } ],
      "commercial_terms" => { "destination" => "Jebel Ali" } })
    questions = InquiryClarificationPrompt.new(inquiry).questions
    assert_not_includes questions, I18n.t("self_service.conversation.prompts.customer")
    assert_includes questions, I18n.t("self_service.conversation.prompts.incoterm")
    assert_includes questions, I18n.t("self_service.conversation.prompts.delivery")
  end
end
