require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  test "build_revision keeps trade term and item structured data" do
    quote = quotes(:one)
    quote.trade_term = "FOB Shanghai"
    first_item = quote.quote_items.first
    first_item.update!(
      specifications: [ { key: "Power", value: "5kW" } ],
      addon_charges: [ { name: "Packaging", amount: "25.00" } ]
    )

    revision = quote.build_revision

    assert_equal "FOB Shanghai", revision.trade_term
    assert_equal first_item.specifications, revision.quote_items.first.specifications
    assert_equal first_item.addon_charges, revision.quote_items.first.addon_charges
  end

  test "lost status requires loss reason" do
    quote = quotes(:one)
    quote.status = "lost"
    quote.loss_reason = ""

    assert_not quote.valid?
    assert_includes quote.errors[:loss_reason], "is required when quote status is Lost"
  end

  test "won status auto-fills final amount from grand total when blank" do
    quote = quotes(:one)
    quote.status = "won"
    quote.final_amount = nil

    assert quote.valid?
    assert_equal quote.grand_total, quote.final_amount
  end
end
