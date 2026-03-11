class CustomerEngagementAnalyticsService
  def initialize(customer)
    @customer = customer
  end

  # Returns a hash of { hour_integer => view_count } for all quote views by this customer.
  # Uses EXTRACT(HOUR FROM ...) in DB — timezone-naive (UTC), suitable for relative pattern analysis.
  #
  # Example: { 9 => 4, 14 => 12, 15 => 8 }
  def view_hour_distribution
    QuoteViewEvent
      .joins(:quote_share)
      .joins("JOIN quotes ON quotes.id = quote_shares.quote_id")
      .where(quotes: { customer_id: @customer.id })
      .group("EXTRACT(HOUR FROM quote_view_events.created_at)::int")
      .count
      .transform_keys(&:to_i)
  end

  # Returns the peak engagement window as "HH:00–HH:00" string, or nil if no data.
  # Window covers the top hour ± 1 hour.
  #
  # Example: "14:00–16:00"
  def best_contact_time
    distribution = view_hour_distribution
    return nil if distribution.empty?

    peak_hour = distribution.max_by { |_hour, count| count }.first
    start_hour = peak_hour
    end_hour   = (peak_hour + 2) % 24

    format("%02d:00–%02d:00", start_hour, end_hour)
  end

  # Returns { best_time: "14:00–16:00", distribution: { 14 => 12, ... }, total_views: 24 }
  def summary
    distribution = view_hour_distribution
    {
      best_time: best_contact_time,
      distribution: distribution,
      total_views: distribution.values.sum
    }
  end
end
