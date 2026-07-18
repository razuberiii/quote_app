require "test_helper"

class QuotePresetTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
  end

  test "container_loading header length is limited" do
    preset = @company.quote_presets.new(
      module_key: "container_loading",
      name: "Loading A",
      payload: {
        "headers" => {
          "variant" => "V" * 60,
          "container_type" => "Container Type",
          "capacity" => "Capacity",
          "note" => "Note"
        },
        "note_enabled" => true,
        "rows" => []
      }
    )

    assert preset.valid?
    assert_equal 40, preset.payload_data.dig("headers", "variant").length
  end

  test "container_loading rows must stay within quote limit" do
    rows = Array.new(Quote::MAX_CONTAINER_LOADING_ROWS + 1) do |idx|
      {
        "variant" => "V#{idx}",
        "container_type" => "40HQ",
        "capacity" => "1",
        "note" => "",
        "position" => idx + 1
      }
    end

    preset = @company.quote_presets.new(
      module_key: "container_loading",
      name: "Loading B",
      payload: { "headers" => {}, "note_enabled" => true, "rows" => rows }
    )

    assert_not preset.valid?
    assert_includes preset.errors[:payload].join, "rows exceed limit"
  end

  test "standard_fee_items keeps only valid rows" do
    preset = @company.quote_presets.create!(
      module_key: "standard_fee_items",
      name: "Fee Preset A",
      payload: {
        "rows" => [
          { "name" => "Shipping", "unit_price" => "5200.5", "quantity" => "1", "position" => 1 },
          { "name" => "", "unit_price" => "100", "quantity" => "1", "position" => 2 },
          { "name" => "Invalid Qty", "unit_price" => "100", "quantity" => "0", "position" => 3 }
        ]
      }
    )

    assert_equal 1, preset.payload_data.fetch("rows", []).size
    first = preset.payload_data["rows"].first
    assert_equal "Shipping", first["name"]
    assert_equal "5200.5", first["unit_price"]
    assert_equal 1, first["quantity"]
  end

  test "module preset limit for regular company is 10" do
    10.times do |idx|
      @company.quote_presets.create!(
        module_key: "advanced_trade_terms",
        name: "Trade #{idx}",
        payload: {}
      )
    end

    blocked = @company.quote_presets.new(
      module_key: "advanced_trade_terms",
      name: "Trade 10",
      payload: {}
    )
    assert_not blocked.valid?
    assert_includes blocked.errors.full_messages.join, "上限"
  end

  test "module preset limit for vip company is 50" do
    owner = @company.users.first
    owner.update!(role: :vip, vip_expires_at: 1.month.from_now)

    50.times do |idx|
      @company.quote_presets.create!(
        module_key: "advanced_logistics",
        name: "Logistics #{idx}",
        payload: {}
      )
    end

    blocked = @company.quote_presets.new(
      module_key: "advanced_logistics",
      name: "Logistics 50",
      payload: {}
    )
    assert_not blocked.valid?
    assert_includes blocked.errors.full_messages.join, "50"
  end
end
