module Admin
  class NotificationsController < BaseController
    def create
      payload = announcement_params
      recipients = User.active
      recipient_count = 0

      ActiveRecord::Base.transaction do
        recipients.find_each(batch_size: 200) do |recipient|
          Notification.create!(
            user: recipient,
            kind: "admin_announcement",
            data: notification_payload(payload)
          )
          recipient_count += 1
        end

        Admin::AuditLogger.log!(
          actor: acting_user_for_audit,
          target: current_user,
          action: :notification_sent,
          metadata: {
            recipient_scope: "all_active_users",
            recipient_count: recipient_count,
            title: payload[:title].to_s,
            has_link: payload[:link_url].present?
          }
        )
      end

      redirect_to admin_root_path, notice: t("admin.notifications.flash.broadcast_sent", count: recipient_count)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_root_path, alert: e.record.errors.full_messages.to_sentence
    end

    private

    def announcement_params
      params.require(:announcement).permit(:title, :message, :link_url)
    end

    def notification_payload(payload)
      {
        title: payload[:title].to_s,
        message: wrap_notification_message(payload[:message].to_s),
        link_url: safe_link_url(payload[:link_url]),
        sender_email: acting_user_for_audit&.email
      }.compact
    end

    def safe_link_url(raw_url)
      value = raw_url.to_s.strip
      return nil if value.blank?
      return value if value.start_with?("/")

      uri = URI.parse(value)
      return value if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      nil
    rescue URI::InvalidURIError
      nil
    end

    def wrap_notification_message(message, line_limit = 44)
      message.to_s.split("\n", -1).map { |line| line.scan(/.{1,#{line_limit}}/mu).join("\n") }.join("\n")
    end
  end
end
