require "test_helper"

class ProductPresetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "index is successful" do
    get product_presets_url

    assert_response :success
    assert_select "h1", I18n.t("product_presets.view.index.title")
  end
end
