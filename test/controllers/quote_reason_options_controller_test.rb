require "test_helper"

class QuoteReasonOptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "create adds company reason option" do
    skip "quote_reason_options table missing" unless defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?

    assert_difference("@user.company.quote_reason_options.count", 1) do
      post quote_reason_options_url, params: {
        quote_reason_option: {
          kind: "win",
          label: "Delivery reliability"
        }
      }
    end

    assert_response :redirect
  end

  test "destroy removes company reason option" do
    skip "quote_reason_options table missing" unless defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?

    option = @user.company.quote_reason_options.create!(kind: "loss", label: "Timeline mismatch", key: "timeline_mismatch")

    assert_difference("@user.company.quote_reason_options.count", -1) do
      delete quote_reason_option_url(option)
    end

    assert_response :redirect
  end
end
