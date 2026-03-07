require "test_helper"

class QuoteChangeSummaryServiceTest < ActiveSupport::TestCase
  test "builds a human readable change summary" do
    diff = {
      modified_items: [
        {
          product_name: "Widget A",
          quantity_before: 2,
          quantity_after: 5,
          unit_price_before: BigDecimal("10"),
          unit_price_after: BigDecimal("9.5")
        }
      ],
      added_items: [ { product_name: "Widget C" } ],
      removed_items: [ { product_name: "Widget B" } ],
      total_before: BigDecimal("100"),
      total_after: BigDecimal("147.5")
    }

    summary = QuoteChangeSummaryService.new(diff: diff, currency: "USD").call

    assert_includes summary, "Widget A quantity updated: 2 -> 5"
    assert_includes summary, "Widget A unit price updated: $10.00 -> $9.50"
    assert_includes summary, "Added new item: Widget C"
    assert_includes summary, "Removed item: Widget B"
    assert_includes summary, "Total updated: $100.00 -> $147.50"
  end
end
