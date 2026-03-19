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

  test "loads product configurator defaults into snapshots on create" do
    product = products(:one)
    spec_preset = product.company.spec_presets.create!(name: "Default Spec", entries_text: "Voltage: 220V")
    addon_preset = product.company.addon_presets.create!(name: "Default Add-on", entries_text: "Warranty: 15")
    product.update!(
      spec_preset_ids: [ spec_preset.id ],
      addon_preset_ids: [ addon_preset.id ],
      default_spec_preset: spec_preset,
      default_addon_preset: addon_preset
    )

    item = QuoteItem.create!(
      quote: quotes(:one),
      product: product,
      description: product.name,
      unit_price: 100,
      quantity: 1
    )

    assert_equal [ { "key" => "Voltage", "value" => "220V" } ], item.spec_snapshot
    assert_equal [ { "name" => "Warranty", "amount" => "15.0" } ], item.addon_snapshot
  end

  test "prevents snapshot edits after quote is sent" do
    item = quote_items(:one)
    item.quote.update!(status: "sent", sent_at: 3.days.ago)

    item.spec_snapshot = [ { key: "Voltage", value: "110V" } ]

    assert_not item.valid?
    assert_includes item.errors[:base], "Specifications and add-ons are locked once the quote is sent"
  end

  test "can select image from current product gallery blob" do
    product = products(:one)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image content"),
      filename: "gallery.png",
      content_type: "image/png"
    )
    product.gallery_images.attach(blob)

    item = QuoteItem.new(
      quote: quotes(:one),
      product: product,
      description: "Item with image",
      unit_price: 100,
      quantity: 1
    )
    item.item_image_blob_id = blob.id

    assert item.valid?
    item.save!
    assert item.item_image.attached?
    assert_equal "product_gallery", item.image_source
  end
end
