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

  test "keeps user-cleared specifications and add-ons on existing item update" do
    product = products(:one)
    spec_preset = product.company.spec_presets.create!(name: "Default Spec Keep", entries_text: "Voltage: 220V")
    addon_preset = product.company.addon_presets.create!(name: "Default Add-on Keep", entries_text: "Warranty: 15")
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
    assert item.specification_pairs.any?
    assert item.addon_charge_entries.any?

    item.specifications_text = ""
    item.addon_charges_text = ""
    item.save!
    item.reload

    assert_equal [], item.specification_pairs
    assert_equal [], item.addon_charge_entries
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

  test "defaults item_type to product_main" do
    item = QuoteItem.create!(
      quote: quotes(:one),
      description: "Default type item",
      unit_price: 100,
      quantity: 1
    )

    assert_equal "product_main", item.item_type
    assert_not item.fee_item?
  end

  test "ordered puts product rows before fee rows" do
    quote = quotes(:one)
    quote.quote_items.create!(
      description: "Port Service Fee",
      unit_price: 80,
      quantity: 1,
      item_type: "fee_port_service"
    )
    quote.quote_items.create!(
      description: "Main Vehicle",
      unit_price: 1000,
      quantity: 1,
      item_type: "product_main"
    )

    ordered_types = quote.quote_items.ordered.map(&:item_type)
    assert_equal "product_main", ordered_types.first
  end
end
