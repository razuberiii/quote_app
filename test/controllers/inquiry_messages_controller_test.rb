require "test_helper"

class InquiryMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    company = Company.create!(name: "Conversation Factory", default_currency: "USD")
    @user = User.create!(company: company, company_role: :owner, username: "conversation_user",
      email: "conversation@example.com", password: "password123", email_verified_at: Time.current)
    @inquiry = company.inquiries.create!(created_by: @user, source_type: "manual", source_text: "Buyer: Atlas Ltd")
    @inquiry.manually_extract!
    sign_in @user
  end

  test "appends a buyer clarification and preserves it in the inquiry source" do
    assert_difference -> { @inquiry.inquiry_messages.count }, 1 do
      post inquiry_inquiry_messages_path(@inquiry), params: { inquiry_message: {
        direction: "buyer", channel: "email", body: "Please quote 12 HPU-380 units in USD, CIF Jebel Ali."
      } }
    end

    message = @inquiry.inquiry_messages.last
    assert_redirected_to inquiry_path(@inquiry, anchor: "conversation")
    assert_includes @inquiry.reload.source_text, "12 HPU-380 units"
    assert_equal "buyer", message.direction
    assert message.change_summary.key?("products_after")
  end

  test "cannot append to another company inquiry" do
    other = Company.create!(name: "Other Factory").inquiries.create!(source_type: "manual", source_text: "Private")
    post inquiry_inquiry_messages_path(other), params: { inquiry_message: { direction: "buyer", channel: "email", body: "No" } }
    assert_response :not_found
  end

  test "rejects an empty follow-up without raising a server error" do
    assert_no_difference -> { @inquiry.inquiry_messages.count } do
      post inquiry_inquiry_messages_path(@inquiry), params: { inquiry_message: {
        direction: "buyer", channel: "email", body: ""
      } }
    end

    assert_redirected_to inquiry_path(@inquiry, anchor: "conversation")
    assert_equal I18n.t("self_service.conversation.invalid_message"), flash[:alert]
  end
end
