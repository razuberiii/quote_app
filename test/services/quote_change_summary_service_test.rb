require "test_helper"

class QuoteChangeSummaryServiceTest < ActiveSupport::TestCase
  test "builds a human readable change summary" do
    diff = {
      modified_items: [
        {
          product_name: "Widget A",
          quantity_before: 2,
          quantity_after: 5,
          quantity_changed: true,
          unit_price_before: BigDecimal("10"),
          unit_price_after: BigDecimal("9.5"),
          unit_price_changed: true
        }
      ],
      added_items: [ { product_name: "Widget C" } ],
      removed_items: [ { product_name: "Widget B" } ],
      total_before: BigDecimal("100"),
      total_after: BigDecimal("147.5")
    }

    summary = QuoteChangeSummaryService.new(diff: diff, currency: "USD").call

    assert_includes summary, I18n.t("quotes.change_summary.overview_title")
    assert_includes summary, I18n.t("quotes.change_summary.overview_updated_items", count: 1)
    assert_includes summary, I18n.t("quotes.change_summary.overview_removed_items", count: 1)
    assert_includes summary, "Widget A"
    assert_includes summary, "$10.00"
    assert_includes summary, "$9.50"
    assert_includes summary, I18n.t("quotes.change_summary.item_bullet", item: "Widget C")
    assert_includes summary, I18n.t("quotes.change_summary.item_bullet", item: "Widget B")
    assert_includes summary, "$100.00"
    assert_includes summary, "$147.50"
    assert_includes summary, I18n.t("quotes.change_summary.pricing_changes_title")
  end
end
