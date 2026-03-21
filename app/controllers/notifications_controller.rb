class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back_or_to root_path
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!
    quote_id = notification.data&.dig("quote_id")
    link_url = notification.data&.dig("link_url")

    if quote_id.present?
      redirect_to quote_path(quote_id)
    elsif safe_redirect_link?(link_url)
      redirect_to link_url, allow_other_host: true
    else
      redirect_to root_path
    end
  end

  def dismiss
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!
    redirect_back_or_to root_path
  end

  def unread_count
    unread_scope = current_user.notifications.unread
    unread_notifications = unread_scope.recent.limit(10)
    menu_html = render_to_string(
      partial: "layouts/notification_bell_menu",
      formats: [ :html ],
      locals: { unread_notifications: unread_notifications }
    )

    render json: {
      count: unread_scope.count,
      menu_html: menu_html
    }
  end

  private

  def safe_redirect_link?(url)
    value = url.to_s.strip
    return false if value.blank?
    return true if value.start_with?("/")

    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end
