require "test_helper"

class DealWorkspaceControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "primary quote workspace pages render" do
    get deals_path
    assert_redirected_to quotes_path

    get quote_path(quotes(:one))
    assert_response :success
    assert_select ".quote-workspace"
    assert_select ".studio-actions a[href='#{preview_quote_path(quotes(:one))}']", text: /预览并发送|发布新版本/

    get library_path
    assert_response :success
    assert_select ".deal-page-header h1", I18n.t("self_service.library.title")
  end

  test "quote list is the canonical commercial home" do
    get quotes_path
    assert_response :success
    assert_select ".quote-core-index"
  end

  test "Library product and workspace settings use Quote-first surfaces" do
    get new_product_path
    assert_response :success
    assert_select ".resource-editor"
    assert_select ".product-edit-panel", count: 0

    get edit_company_settings_path
    assert_response :success
    assert_select ".settings-editor"
    assert_select ".team-members-panel", count: 0
  end

  test "removed dashboard is not routable" do
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/dashboard") }
  end
end
