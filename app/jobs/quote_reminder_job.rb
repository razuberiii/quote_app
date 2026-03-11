class QuoteReminderJob < ApplicationJob
  queue_as :default

  def perform
    Quote
      .not_archived
      .latest_versions
      .includes(:customer, :quote_shares)
      .find_each do |quote|
        next unless quote.can_send_reminder?

        QuoteReminderSender.new(quote).call
      rescue StandardError => e
        Rails.logger.warn("QuoteReminderJob skipped quote=#{quote.id}: #{e.class} #{e.message}")
      end
  end
end
