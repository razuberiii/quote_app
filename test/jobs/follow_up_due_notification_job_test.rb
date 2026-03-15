require "test_helper"

class FollowUpDueNotificationJobTest < ActiveJob::TestCase
  test "creates follow_up_due action item for due customer" do
    user = users(:one)
    company = user.company
    customer = customers(:one)
    customer.update!(next_follow_up_date: Date.current)

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-DUE-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 2.days.ago,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Due follow-up quote",
          unit_price: 100,
          quantity: 1
        }
      ]
    )

    assert_difference("ActionItem.count", 1) do
      FollowUpDueNotificationJob.perform_now
    end

    action_item = ActionItem.order(:created_at).last
    assert_equal "follow_up_due", action_item.action_type
    assert_equal customer, action_item.reference.customer
  end

  test "does not create follow_up_due action item for lost customer" do
    user = users(:one)
    company = user.company
    customer = customers(:one)
    customer.update!(status: "lost", next_follow_up_date: Date.current)

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-DUE-SKIP-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 2.days.ago,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Skip due follow-up quote",
          unit_price: 100,
          quantity: 1
        }
      ]
    )

    assert_no_difference("ActionItem.count") do
      FollowUpDueNotificationJob.perform_now
    end
  end
end
