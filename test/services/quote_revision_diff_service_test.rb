require "test_helper"

class QuoteRevisionDiffServiceTest < ActiveSupport::TestCase
  test "detects added removed and modified items between adjacent revisions" do
    company = companies(:one)
    customer = customers(:one)

    previous = company.quotes.new(
      customer: customer,
      quote_no: "QT-DIFF-001",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      issued_on: Date.current
    )
    previous.quote_items.build(description: "Widget A", quantity: 2, unit_price: 10)
    previous.quote_items.build(description: "Widget B", quantity: 1, unit_price: 30)
    previous.save!

    current = company.quotes.new(
      customer: customer,
      quote_no: "QT-DIFF-001",
      revision_number: 2,
      currency: "USD",
      status: "draft",
      issued_on: Date.current
    )
    current.quote_items.build(description: "Widget A", quantity: 3, unit_price: 12)
    current.quote_items.build(description: "Widget C", quantity: 4, unit_price: 8)
    current.save!

    diff = QuoteRevisionDiffService.new(new_quote: current, old_quote: previous).call

    assert_equal 1, diff[:modified_items].size
    assert_equal "Widget A", diff[:modified_items].first[:product_name]
    assert_equal 1, diff[:added_items].size
    assert_equal "Widget C", diff[:added_items].first[:product_name]
    assert_equal 1, diff[:removed_items].size
    assert_equal "Widget B", diff[:removed_items].first[:product_name]
    assert_equal BigDecimal("50"), diff[:total_before]
    assert_equal BigDecimal("68"), diff[:total_after]
  end
end
