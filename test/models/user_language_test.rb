require "test_helper"

class UserLanguageTest < ActiveSupport::TestCase
  test "new self service users default to Chinese" do
    user = User.new(email: "new-user@example.com", password: "password123", username: "new_user", company: companies(:one))
    user.valid?
    assert_equal "zh-CN", user.language
  end
end
