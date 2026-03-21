require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "unread_count returns count and synced menu html" do
    Notification.create!(
      user: @user,
      kind: "quote_viewed",
      data: {
        quote_id: quotes(:one).id,
        quote_no: quotes(:one).quote_no,
        customer_name: customers(:one).name
      }
    )

    get unread_count_notifications_url, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload["count"]
    assert_includes payload["menu_html"], "notification-list"
    assert_includes payload["menu_html"], quotes(:one).quote_no.to_s
  end

  test "unread_count returns empty menu when there are no unread notifications" do
    @user.notifications.unread.delete_all

    get unread_count_notifications_url, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 0, payload["count"]
    assert_includes payload["menu_html"], I18n.t("notifications.empty")
  end

  test "mark_read redirects to link_url for admin announcement" do
    notification = Notification.create!(
      user: @user,
      kind: "admin_announcement",
      data: {
        title: "Announcement",
        message: "System upgraded",
        link_url: "https://example.com/changelog"
      }
    )

    get mark_read_notification_url(notification)

    assert_redirected_to "https://example.com/changelog"
    notification.reload
    assert notification.read_at.present?
  end

  test "dismiss marks notification as read without opening link" do
    notification = Notification.create!(
      user: @user,
      kind: "admin_announcement",
      data: {
        title: "Announcement",
        message: "System upgraded"
      }
    )

    patch dismiss_notification_url(notification)

    assert_redirected_to root_path
    notification.reload
    assert notification.read_at.present?
  end
end
