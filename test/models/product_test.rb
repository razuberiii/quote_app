require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "normalizes default specs and add-ons from configurator fields" do
    product = Product.new(
      company: companies(:one),
      name: "Configurator Pump",
      sku: "cfg-01",
      default_price: 120,
      price_currency: "usd",
      default_specs: [
        { name: "Voltage", value: "220V" },
        { name: "Frequency", value: "50Hz" }
      ],
      default_addons: [
        { name: "Installation Kit", price: "120" },
        { name: "Extended Warranty", price: "50.5" }
      ]
    )

    assert product.valid?
    assert_equal [ { name: "Voltage", value: "220V" }, { name: "Frequency", value: "50Hz" } ], product.effective_default_specs
    assert_equal [ { name: "Installation Kit", price: "120.0" }, { name: "Extended Warranty", price: "50.5" } ], product.effective_default_addons
    assert_equal "Voltage: 220V\nFrequency: 50Hz", product.default_specification
  end

  test "falls back to legacy default specification when configurator specs are blank" do
    product = products(:one)
    product.default_specs = []
    product.default_specification = "Power: 5kW\nVoltage: 220V"
    product.valid?

    assert_equal [ { name: "Power", value: "5kW" }, { name: "Voltage", value: "220V" } ], product.effective_default_specs
  end

  test "uses bound default presets when present" do
    company = companies(:one)
    spec_preset = company.spec_presets.create!(name: "Japan Spec", entries_text: "Voltage: 100V\nFrequency: 50Hz")
    addon_preset = company.addon_presets.create!(name: "Japan Add-ons", entries_text: "Warranty: 25\nAdapter: 8")

    product = Product.new(
      company: company,
      name: "Preset Pump",
      sku: "preset-01",
      default_price: 120,
      price_currency: "USD",
      spec_preset_ids: [ spec_preset.id ],
      addon_preset_ids: [ addon_preset.id ],
      default_spec_preset: spec_preset,
      default_addon_preset: addon_preset
    )

    assert product.valid?
    assert_equal [ { name: "Voltage", value: "100V" }, { name: "Frequency", value: "50Hz" } ], product.effective_default_specs
    assert_equal [ { name: "Warranty", price: "25.0" }, { name: "Adapter", price: "8.0" } ], product.effective_default_addons
    assert_equal "Voltage: 100V\nFrequency: 50Hz", product.default_specification
  end
end
