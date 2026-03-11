require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "normalizes and formats phone country code for display and whatsapp" do
    customer = Customer.new(
      company: companies(:one),
      name: "Acme",
      status: "new",
      customer_level: "normal",
      phone_country_code: "81",
      phone: "(090) 1234-5678"
    )

    customer.valid?

    assert_equal "+81", customer.phone_country_code
    assert_equal "+81 (090) 1234-5678", customer.formatted_phone
    assert_equal "8109012345678", customer.whatsapp_phone
  end

  test "mark_followed_today! creates event when user is provided" do
    customer = customers(:one)
    user = users(:one)

    assert_difference("CustomerFollowUpEvent.count", 1) do
      event = customer.mark_followed_today!(user: user, channel: "manual", note: "Checked in")

      assert_equal customer, event.customer
      assert_equal user, event.user
      assert_equal "manual", event.channel
      assert_equal "Checked in", event.note
    end

    customer.reload
    assert_equal Date.current, customer.last_follow_up_date
    assert_equal Date.current + 3.days, customer.next_follow_up_date
  end
end
