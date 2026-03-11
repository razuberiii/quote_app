class ChannelUsageAnalyticsService
  def initialize(company:)
    @company = company
  end

  # Returns total follow-up events grouped by channel.
  # { "whatsapp" => 34, "email" => 28, "manual" => 61, "call" => 12, "linkedin" => 5 }
  def channel_distribution
    CustomerFollowUpEvent
      .joins(:customer)
      .where(customers: { company_id: @company.id })
      .group(:channel)
      .count
      .sort_by { |_k, v| -v }
      .to_h
  end

  # Returns channel trend over the last N days (grouped by day × channel).
  # Useful for sparkline charts in the future.
  # Returns array of { date:, channel:, count: } sorted by date.
  def channel_trend(days: 30)
    CustomerFollowUpEvent
      .joins(:customer)
      .where(customers: { company_id: @company.id })
      .where(contacted_at: days.days.ago..Time.current)
      .group("DATE(contacted_at)", :channel)
      .count
      .map { |(date, channel), count| { date: date, channel: channel, count: count } }
      .sort_by { |row| row[:date] }
  end

  # Structured for future reply_rate extension:
  # [
  #   { channel: "whatsapp", total: 34, replied: nil, reply_rate: nil },
  #   ...
  # ]
  def summary
    channel_distribution.map do |channel, total|
      {
        channel:    channel,
        total:      total,
        replied:    nil,   # reserved for future reply tracking
        reply_rate: nil    # reserved: replied.to_f / total * 100 when available
      }
    end
  end
end
