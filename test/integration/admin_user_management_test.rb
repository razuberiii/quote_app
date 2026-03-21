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

  test "admin can grant user one month vip and create audit log" do
    now = Time.current
    travel_to(now) do
      assert_difference("AuditLog.count", 1) do
        post grant_vip_admin_user_path(@user)
      end
    end

    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "vip", @user.role
    assert_in_delta 1.month.from_now.to_i, @user.vip_expires_at.to_i, 2

    log = AuditLog.order(:created_at).last
    assert_equal "vip_extended", log.action
    assert_equal @admin.id, log.actor_id
    assert_equal "user", log.metadata["before_role"]
    assert_equal "vip", log.metadata["after_role"]
    assert_nil log.metadata["before_vip_expires_at"]
    assert log.metadata["after_vip_expires_at"].present?
  end

  test "grant vip stacks from existing vip expiry" do
    @user.update!(role: :vip, vip_expires_at: 15.days.from_now)
    previous_expiry = @user.vip_expires_at

    post grant_vip_admin_user_path(@user)

    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "vip", @user.role
    assert_in_delta (previous_expiry + 1.month).to_i, @user.vip_expires_at.to_i, 2
  end

  test "admin cannot grant vip to self because it changes own role" do
    assert_no_difference("AuditLog.count") do
      post grant_vip_admin_user_path(@admin)
    end

    assert_redirected_to admin_user_path(@admin)
    @admin.reload
    assert_equal "admin", @admin.role
    assert_nil @admin.vip_expires_at
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

  test "admin can send single notification to user" do
    long_line = "X" * 100

    assert_difference("Notification.count", 1) do
      post send_notification_admin_user_path(@user), params: {
        announcement: {
          title: "Product update",
          message: long_line,
          link_url: "https://rubusoo.com/updates"
        }
      }
    end

    assert_redirected_to admin_user_path(@user)
    notification = Notification.order(:created_at).last
    assert_equal @user.id, notification.user_id
    assert_equal "admin_announcement", notification.kind
    assert_equal "Product update", notification.data["title"]
    assert_includes notification.data["message"], "\n"

    log = AuditLog.order(:created_at).last
    assert_equal "notification_sent", log.action
    assert_equal @admin.id, log.actor_id
    assert_equal "single_user", log.metadata["recipient_scope"]
  end

  test "admin cannot impersonate inactive user" do
    @user.update!(status: :suspended)

    assert_no_difference("AuditLog.count") do
      post impersonate_admin_user_path(@user)
    end

    assert_redirected_to admin_user_path(@user)
  end

  test "impersonation auto-exits to admin when target becomes suspended" do
    post impersonate_admin_user_path(@user)
    assert_redirected_to dashboard_path

    @user.update!(status: :suspended)

    get dashboard_path
    assert_redirected_to admin_root_path
  end
end
