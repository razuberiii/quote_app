require "test_helper"

class ActionItemGeneratorTest < ActiveSupport::TestCase
  test "creates unresolved action items without duplicates" do
    user = users(:one)
    company = user.company
    customer = customers(:one)

    viewed_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-ACTION-001",
      revision_number: 1,
      currency: "USD",
      status: "viewed",
      sent_at: 4.days.ago,
      viewed_at: 2.days.ago,
      issued_on: Date.current
    )
    viewed_quote.quote_items.build(description: "Widget A", quantity: 1, unit_price: 10)
    viewed_quote.save!

    expiring_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-ACTION-002",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 4.days.ago,
      valid_until: 1.day.from_now.to_date,
      issued_on: Date.current
    )
    expiring_quote.quote_items.build(description: "Widget B", quantity: 1, unit_price: 10)
    expiring_quote.save!

    generator = ActionItemGenerator.new(user: user)

    assert_difference("ActionItem.count", 3) do
      generator.call
    end

    assert_no_difference("ActionItem.count") do
      generator.call
    end

    assert_equal 3, user.action_items.unresolved.count
  end
end
