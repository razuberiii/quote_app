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
    redirect_to quote_id.present? ? quote_path(quote_id) : root_path
  end

  def unread_count
    render json: { count: current_user.notifications.unread.count }
  end
end
