require "test_helper"

class SuspendedEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(role: :user, status: :active, email_verified_at: Time.current)
    sign_in @user
  end

  test "suspended signed-in user is logged out on next request" do
    @user.update!(status: :suspended)

    get dashboard_path
    assert_redirected_to suspended_path

    get dashboard_path
    assert_redirected_to new_user_session_path
  end
end
