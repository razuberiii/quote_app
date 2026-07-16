require "test_helper"

class AdminConsoleAccessTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, status: :active, email_verified_at: Time.current)

    @member = users(:two)
    @member.update!(role: :user, status: :active, email_verified_at: Time.current)
  end

  test "admin can open admin dashboard" do
    sign_in @admin

    get admin_root_path
    assert_response :success
  end

  test "non-admin cannot open admin dashboard" do
    sign_in @member

    get admin_root_path
    assert_redirected_to root_path
  end

  test "admin login redirects to admin dashboard" do
    post user_session_path, params: { user: { login: @admin.email, password: "password123" } }

    assert_redirected_to admin_root_path
    @admin.reload
    assert @admin.last_login_at.present?
  end

  test "admin can login with username" do
    post user_session_path, params: { user: { login: @admin.username, password: "password123" } }

    assert_redirected_to admin_root_path
  end

  test "suspended user cannot login" do
    @member.update!(status: :suspended)

    post user_session_path, params: { user: { login: @member.email, password: "password123" } }

    assert_redirected_to suspended_path
  end
end
