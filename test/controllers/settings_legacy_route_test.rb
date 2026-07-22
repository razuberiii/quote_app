require "test_helper"

class SettingsLegacyRouteTest < ActionDispatch::IntegrationTest
  test "legacy company settings path redirects to the canonical editor" do
    get "/settings/company"

    assert_redirected_to "/company_settings/edit"
  end
end
