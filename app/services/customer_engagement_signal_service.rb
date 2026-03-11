class CustomerEngagementSignalService
  SILENCE_THRESHOLD_DAYS = 5

  def initialize(customer)
    @customer = customer
  end

  # Returns true when the customer previously engaged (viewed a quote) but:
  # - The last view was more than SILENCE_THRESHOLD_DAYS ago
  # - No follow-up was recorded after that last view
  def silent_customer?
    last_view = latest_view_at
    return false if last_view.blank?
    return false if last_view >= SILENCE_THRESHOLD_DAYS.days.ago

    follow_up_date = @customer.last_follow_up_date
    follow_up_date.blank? || follow_up_date.to_date < last_view.to_date
  end

  # Returns days since last customer view, or nil.
  def days_since_last_view
    last_view = latest_view_at
    return nil if last_view.blank?

    (Date.current - last_view.to_date).to_i
  end

  # Returns the latest_view_at timestamp across all quote_shares for this customer's quotes.
  def latest_view_at
    @latest_view_at ||= begin
      Quote
        .joins(:quote_shares)
        .where(customer_id: @customer.id)
        .where.not(quote_shares: { last_viewed_at: nil })
        .maximum("quote_shares.last_viewed_at")
    end
  end

  # Returns channel usage counts for this customer.
  # { "whatsapp" => 5, "email" => 3, "manual" => 7, ... }
  def channel_breakdown
    @customer
      .customer_follow_up_events
      .group(:channel)
      .count
  end

  # Full signal payload for use in radar / UI.
  def signal_payload
    return nil unless silent_customer?

    days = days_since_last_view
    {
      type: "customer_silent",
      priority: "watch",
      customer: @customer,
      days_since_last_view: days,
      last_viewed_at: latest_view_at,
      label: I18n.t("analytics.customer_silent.label"),
      detail: I18n.t("analytics.customer_silent.detail", days: days)
    }
  end
end
