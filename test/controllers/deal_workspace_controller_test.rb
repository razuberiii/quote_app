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

  test "legacy entries lead to deal workspace" do
    get dashboard_path
    assert_redirected_to "/inbox"

    get all_quotes_path
    assert_redirected_to "/deals"
  end
end
