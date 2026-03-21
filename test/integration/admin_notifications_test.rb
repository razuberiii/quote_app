require "test_helper"

class AdminNotificationsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, status: :active, email_verified_at: Time.current)

    @user = users(:two)
    @user.update!(role: :user, status: :active, email_verified_at: Time.current)

    sign_in @admin
  end

  test "admin can broadcast notification to all active users" do
    suspended_user = User.create!(
      email: "suspended@example.com",
      password: "password123",
      password_confirmation: "password123",
      company: @admin.company,
      role: :user,
      status: :suspended,
      email_verified_at: Time.current
    )

    assert_difference("Notification.count", User.active.count) do
      post admin_notifications_path, params: {
        announcement: {
          title: "Release note",
          message: "New admin tools are live.",
          link_url: "https://rubusoo.com/updates"
        }
      }
    end

    assert_redirected_to admin_root_path
    assert_equal 0, Notification.where(user_id: suspended_user.id, kind: "admin_announcement").count

    log = AuditLog.order(:created_at).last
    assert_equal "notification_sent", log.action
    assert_equal @admin.id, log.actor_id
    assert_equal "all_active_users", log.metadata["recipient_scope"]
  end

  test "broadcast notification wraps very long lines" do
    long_line = "X" * 120

    post admin_notifications_path, params: {
      announcement: {
        title: "Long message",
        message: long_line
      }
    }

    assert_redirected_to admin_root_path
    message = Notification.where(kind: "admin_announcement").order(:created_at).last.data["message"]
    assert_includes message, "\n"
  end
end
