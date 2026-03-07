require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "create persists configurator defaults" do
    spec_preset = companies(:one).spec_presets.create!(name: "Export Spec", entries_text: "Voltage: 220V\nFrequency: 50Hz")
    addon_preset = companies(:one).addon_presets.create!(name: "Export Add-ons", entries_text: "Installation Kit: 80")

    assert_difference("Product.count", 1) do
      post products_url, params: {
        product: {
          name: "Configurator Product",
          sku: "CFG-100",
          default_price: 99.5,
          price_currency: "USD",
          spec_preset_ids: [ spec_preset.id ],
          addon_preset_ids: [ addon_preset.id ],
          default_spec_preset_id: spec_preset.id,
          default_addon_preset_id: addon_preset.id
        }
      }
    end

    product = Product.order(:created_at).last
    assert_redirected_to product_url(product)
    assert_equal spec_preset.id, product.default_spec_preset_id
    assert_equal addon_preset.id, product.default_addon_preset_id
    assert_equal "Voltage", product.effective_default_specs.first[:name]
    assert_equal "Installation Kit", product.effective_default_addons.first[:name]
  end
end
