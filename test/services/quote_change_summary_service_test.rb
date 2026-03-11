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

    assert_includes summary, I18n.t("quotes.change_summary.quantity_updated", product: "Widget A", before: 2, after: 5)
    assert_includes summary, "Widget A"
    assert_includes summary, "$10.00"
    assert_includes summary, "$9.50"
    assert_includes summary, I18n.t("quotes.change_summary.added_item", product: "Widget C")
    assert_includes summary, I18n.t("quotes.change_summary.removed_item", product: "Widget B")
    assert_includes summary, "$100.00"
    assert_includes summary, "$147.50"
    assert_includes summary, I18n.t("quotes.change_summary.total_updated", before: "$100.00", after: "$147.50").split(":").first
  end
end
