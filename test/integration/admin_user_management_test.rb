require "test_helper"

class AdminUserManagementTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, status: :active, email_verified_at: Time.current)

    @user = users(:two)
    @user.update!(role: :user, status: :active, email_verified_at: Time.current)

    sign_in @admin
  end

  test "admin can change user role and create audit log" do
    assert_difference("AuditLog.count", 1) do
      patch update_role_admin_user_path(@user), params: { user: { role: "vip" } }
    end

    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "vip", @user.role

    log = AuditLog.order(:created_at).last
    assert_equal "role_changed", log.action
    assert_equal @admin.id, log.actor_id
    assert_equal "user", log.metadata["before_role"]
    assert_equal "vip", log.metadata["after_role"]
  end

  test "admin cannot change own role" do
    patch update_role_admin_user_path(@admin), params: { user: { role: "user" } }

    assert_redirected_to admin_user_path(@admin)
    @admin.reload
    assert_equal "admin", @admin.role
  end

  test "admin can suspend and reactivate user with audit logs" do
    assert_difference("AuditLog.count", 2) do
      patch update_status_admin_user_path(@user), params: { user: { status: "suspended" } }
      patch update_status_admin_user_path(@user), params: { user: { status: "active" } }
    end

    @user.reload
    assert_equal "active", @user.status
  end

  test "admin cannot impersonate admin user" do
    other_admin = User.create!(
      email: "other-admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      company: @admin.company,
      role: :admin,
      status: :active,
      email_verified_at: Time.current
    )

    assert_no_difference("AuditLog.count") do
      post impersonate_admin_user_path(other_admin)
    end

    assert_redirected_to admin_user_path(other_admin)
  end

  test "admin can start and stop impersonation with audit logs" do
    assert_difference("AuditLog.count", 2) do
      post impersonate_admin_user_path(@user)
      assert_redirected_to dashboard_path

      delete admin_impersonation_path
      assert_redirected_to admin_root_path
    end

    actions = AuditLog.order(:created_at).last(2).map(&:action)
    assert_equal [ "impersonation_started", "impersonation_stopped" ], actions
  end
end
