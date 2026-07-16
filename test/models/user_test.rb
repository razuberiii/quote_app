require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "finds a user for login by username or email without case sensitivity" do
    user = users(:one)
    user.update!(username: "quote_owner")

    assert_equal user, User.find_for_database_authentication(login: "QUOTE_OWNER")
    assert_equal user, User.find_for_database_authentication(login: user.email.upcase)
  end
end
