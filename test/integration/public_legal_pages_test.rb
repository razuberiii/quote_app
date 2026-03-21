require "test_helper"

class PublicLegalPagesTest < ActionDispatch::IntegrationTest
  test "privacy and terms pages are publicly accessible" do
    get privacy_path
    assert_response :success
    assert_includes @response.body, "Rubusoo"

    get terms_path
    assert_response :success
    assert_includes @response.body, "Rubusoo"
  end
end
