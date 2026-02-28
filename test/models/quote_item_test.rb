require "test_helper"

class QuoteItemTest < ActiveSupport::TestCase
  test "parses specifications and add-ons from text and computes amount" do
    item = QuoteItem.new(
      quote: quotes(:one),
      description: "Test Item",
      unit_price: 100,
      quantity: 2,
      specifications_text: "Power: 5kW\nVoltage: 220V",
      addon_charges_text: "Packaging: 30\nInstallation: 20"
    )

    assert item.valid?
    assert_equal 250.to_d, item.amount.to_d
    assert_equal 2, item.specification_pairs.size
    assert_equal 2, item.addon_charge_entries.size
    assert_equal 50.to_d, item.addon_total.to_d
  end

  test "ignores malformed addon lines" do
    item = QuoteItem.new(
      quote: quotes(:one),
      description: "Test Item",
      unit_price: 100,
      quantity: 1,
      addon_charges_text: "Invalid\nShipping: abc\nWarranty: 15"
    )

    assert item.valid?
    assert_equal 115.to_d, item.amount.to_d
    assert_equal [ "Warranty" ], item.addon_charge_entries.map { |entry| entry[:name] }
  end
end
