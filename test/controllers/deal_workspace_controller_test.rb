require "test_helper"

class DealWorkspaceControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "primary deal workspace pages render" do
    get inbox_index_path
    assert_response :success
    assert_select "h1", "Inbox"

    get deals_path
    assert_response :success
    assert_select "h1", "Deals"

    get deal_path(quotes(:one))
    assert_response :success
    assert_select ".deal-primary-action"
    assert_select ".deal-tabs a", text: "Conversation"

    get library_path
    assert_response :success
    assert_select "h1", "Library"
  end

  test "legacy quote list leads to deal workspace" do
    get all_quotes_path
    assert_redirected_to "/deals"
  end

  test "Library product and workspace settings use Deal-first surfaces" do
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
