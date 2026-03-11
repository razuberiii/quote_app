require "test_helper"

class ActionItemGeneratorTest < ActiveSupport::TestCase
  test "creates unresolved action items without duplicates" do
    user = users(:one)
    company = user.company
    customer = customers(:one)

    stale_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-ACTION-001",
      revision_number: 1,
      currency: "USD",
      status: "negotiating",
      sent_at: nil,
      issued_on: Date.current,
      updated_at: 8.days.ago
    )
    stale_quote.quote_items.build(description: "Widget A", quantity: 1, unit_price: 10)
    stale_quote.save!
    stale_quote.update_column(:updated_at, 8.days.ago)

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

    ignored_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-ACTION-003",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      issued_on: Date.current
    )
    ignored_quote.quote_items.build(description: "Widget C", quantity: 1, unit_price: 10)
    ignored_quote.save!

    generator = ActionItemGenerator.new(user: user)

    assert_difference("ActionItem.count", 4) do
      generator.call
    end

    assert_no_difference("ActionItem.count") do
      generator.call
    end

    action_types = user.action_items.unresolved.pluck(:action_type)
    assert_equal 4, action_types.size
    assert_includes action_types, "follow_up_due"
    assert_includes action_types, "stalled_negotiation"
    assert_includes action_types, "expiring_soon"
    assert_includes action_types, "not_viewed_7d"
  end

  test "creates follow_up_due action item for customer due today" do
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
          description: "Due item",
          unit_price: 100,
          quantity: 1
        }
      ]
    )

    items = ActionItemGenerator.new(user: user).call

    due_item = items.find { |item| item.action_type == "follow_up_due" }
    assert_equal customer, due_item.reference.customer
  end

  test "creates win_reason_missing action item for won quote without reason" do
    user = users(:one)
    company = user.company
    customer = customers(:one)

    quote = Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-WIN-MISS-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency: "USD",
      status: "won",
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Won item",
          unit_price: 100,
          quantity: 1
        }
      ],
      win_reason: "price_accepted",
      win_reason_detail: "ok"
    )
    quote.update_columns(win_reason: nil, win_reason_detail: nil)

    items = ActionItemGenerator.new(user: user).call
    missing = items.find { |item| item.action_type == "win_reason_missing" }

    assert_not_nil missing
    assert_equal quote.id, missing.reference_id
  end
end
