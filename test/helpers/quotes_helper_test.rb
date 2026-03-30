require "test_helper"

class QuotesHelperTest < ActionView::TestCase
  test "quote_container_loading_note_column? returns true when any row has note" do
    rows = [
      { variant: "A", container_type: "40HQ", capacity: "4", note: "" },
      { variant: "B", container_type: "40HQ", capacity: "2", note: "with windows" }
    ]

    assert quote_container_loading_note_column?(rows)
  end

  test "quote_container_loading_note_column? returns false when all notes are blank" do
    rows = [
      { variant: "A", container_type: "40HQ", capacity: "4", note: "" },
      { variant: "B", container_type: "40HQ", capacity: "2", note: "   " }
    ]

    assert_not quote_container_loading_note_column?(rows)
  end

  test "quote_public_snapshot_item_specs reads canonical key/value rows" do
    item = {
      "specifications" => [
        { "key" => "Voltage", "value" => "220V" },
        { "key" => "Power", "value" => "5kW" }
      ]
    }

    assert_equal(
      [
        { key: "Voltage", value: "220V" },
        { key: "Power", value: "5kW" }
      ],
      quote_public_snapshot_item_specs(item)
    )
  end

  test "quote_public_snapshot_item_addons reads canonical name/amount rows" do
    item = {
      "addon_charges" => [
        { "name" => "Battery", "amount" => "200.0" },
        { "name" => "Bracket", "amount" => "80" }
      ]
    }

    assert_equal(
      [
        { name: "Battery", amount: "200.0" },
        { name: "Bracket", amount: "80.0" }
      ],
      quote_public_snapshot_item_addons(item)
    )
  end

  test "quote_pdf_primary_item_image_blob_ids returns set of representative blob ids" do
    attachment_one = Struct.new(:blob_id).new(101)
    attachment_two = Struct.new(:blob_id).new(202)
    item_one = Struct.new(:effective_image_attachment).new(attachment_one)
    item_two = Struct.new(:effective_image_attachment).new(attachment_two)
    item_three = Struct.new(:effective_image_attachment).new(nil)

    ids = quote_pdf_primary_item_image_blob_ids([ item_one, item_two, item_three ])

    assert_equal Set.new(%w[101 202]), ids
  end

  test "quote_pdf_filtered_detail_picture_cards excludes duplicated main item images" do
    helper = self
    helper.define_singleton_method(:quote_detail_picture_image_src) do |item, inline_for_pdf: false|
      "data:image/png;base64,#{item[:image_blob_id]}-#{inline_for_pdf ? 'pdf' : 'web'}"
    end

    cards = quote_pdf_filtered_detail_picture_cards(
      [
        { image_blob_id: "101", caption: "main", position: 1 },
        { image_blob_id: "303", caption: "detail", position: 2 }
      ],
      main_item_blob_ids: Set.new([ "101" ]),
      inline_for_pdf: true
    )

    assert_equal 1, cards.size
    assert_equal "303", cards.first[:image_blob_id]
    assert_match(/303-pdf/, cards.first[:image_src])
  end
end
