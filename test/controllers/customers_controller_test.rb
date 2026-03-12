require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @customer = customers(:one)
    sign_in @user
  end

  test "index is successful" do
    get customers_url
    assert_response :success
  end

  test "show is successful for company customer" do
    get customer_url(@customer)
    assert_response :success
  end

  test "log_follow_up creates a manual follow-up event" do
    assert_difference("CustomerFollowUpEvent.count", 1) do
      post log_follow_up_customer_url(@customer), params: { follow_up: { message: "Checked in with buyer" } }
    end

    assert_redirected_to customer_url(@customer)
    event = CustomerFollowUpEvent.order(:created_at).last
    assert_equal "manual", event.channel
    assert_equal "Checked in with buyer", event.note
    assert_equal @user, event.user
  end

  test "mark_follow_up updates follow-up status without saving assistant draft text" do
    assert_difference("CustomerFollowUpEvent.count", 1) do
      post mark_follow_up_customer_url(@customer)
    end

    assert_redirected_to customer_url(@customer)
    event = CustomerFollowUpEvent.order(:created_at).last
    assert_equal "manual", event.channel
    assert_nil event.note
    assert_equal @user, event.user
  end

  test "send_follow_up_email sends mail and logs an event" do
    @customer.update!(email: "buyer@example.com")
    ActionMailer::Base.deliveries.clear

    previous_skip = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    assert_difference("CustomerFollowUpEvent.count", 1) do
      post send_follow_up_email_customer_url(@customer), params: { follow_up: { message: "Quick follow-up" } }
    end

    assert_redirected_to customer_url(@customer)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "email", CustomerFollowUpEvent.order(:created_at).last.channel
  ensure
    if previous_skip.nil?
      ENV.delete("SKIP_TURNSTILE_VERIFICATION")
    else
      ENV["SKIP_TURNSTILE_VERIFICATION"] = previous_skip
    end
  end

  test "send_follow_up_email blocks resend during cooldown" do
    @customer.update!(email: "buyer@example.com")
    @customer.customer_follow_up_events.create!(
      user: @user,
      channel: "email",
      contacted_at: 2.minutes.ago,
      note: "Recent follow-up"
    )

    ActionMailer::Base.deliveries.clear

    previous_skip = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    assert_no_difference("CustomerFollowUpEvent.count") do
      post send_follow_up_email_customer_url(@customer), params: { follow_up: { message: "Another follow-up" } }
    end

    assert_redirected_to customer_url(@customer)
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_equal I18n.t("follow_up.flash.email_cooldown", minutes: 8), flash[:alert]
  ensure
    if previous_skip.nil?
      ENV.delete("SKIP_TURNSTILE_VERIFICATION")
    else
      ENV["SKIP_TURNSTILE_VERIFICATION"] = previous_skip
    end
  end

  test "send_follow_up_whatsapp returns a link and logs an event" do
    @customer.update!(phone_country_code: "+52", phone: "123456789")

    assert_difference("CustomerFollowUpEvent.count", 1) do
      post send_follow_up_whatsapp_customer_url(@customer, format: :json), params: { follow_up: { message: "Hola" } }, as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_match %r{\Ahttps://wa.me/}, payload["url"]
    assert_equal "whatsapp", CustomerFollowUpEvent.order(:created_at).last.channel
  end
end
