class QuoteSignalService
  QuoteSignal = Struct.new(
    :type,
    :priority,
    :recommended_action,
    :label,
    :cta_label,
    :metadata,
    keyword_init: true
  )

  PRIORITY_ORDER = {
    "urgent" => 0,
    "risk" => 1,
    "watch" => 2,
    "normal" => 3
  }.freeze

  def initialize(quote)
    @quote = quote
  end

  def call
    return default_signal unless quote.present?

    revision_requested_signal ||
      expiring_soon_signal ||
      hot_engagement_no_follow_up_signal ||
      viewed_no_follow_up_signal ||
      not_viewed_7d_signal ||
      not_viewed_3d_signal ||
      stalled_negotiation_signal ||
      default_signal
  end

  def self.priority_rank(priority)
    PRIORITY_ORDER.fetch(priority.to_s, 9)
  end

  private

  attr_reader :quote

  def revision_requested_signal
    return nil unless quote.changes_requested_at.present?

    signal("revision_requested", "urgent", "prepare_revision")
  end

  def expiring_soon_signal
    days = quote.expires_in_days
    return nil unless quote.active_for_signal?
    return nil if days.nil? || days.negative? || days > 3

    signal("expiring_soon", "urgent", "renew_quote", expires_in_days: days)
  end

  def hot_engagement_no_follow_up_signal
    return nil unless quote.active_for_signal?
    return nil unless quote.engagement_label == :hot
    return nil unless customer_last_follow_up_before?(2.days.ago.to_date)

    signal(
      "hot_engagement_no_follow_up",
      "urgent",
      "follow_up_now",
      view_count: quote.view_count,
      engagement_score: quote.engagement_score
    )
  end

  def viewed_no_follow_up_signal
    return nil unless quote.active_for_signal?
    return nil unless quote.view_count.positive?

    viewed_at = quote.last_viewed_at
    return nil if viewed_at.blank?
    return nil unless customer_last_follow_up_before?(viewed_at.to_date)

    signal(
      "viewed_no_follow_up",
      "watch",
      "follow_up",
      view_count: quote.view_count,
      last_viewed_at: viewed_at
    )
  end

  def not_viewed_7d_signal
    return nil unless quote.active_for_signal?
    return nil unless quote.sent_at.present?
    return nil unless quote.view_count.zero?
    return nil unless quote.sent_at <= 7.days.ago

    signal(
      "not_viewed_7d",
      "risk",
      "resend_reminder",
      days_since_sent: days_since(quote.sent_at)
    )
  end

  def not_viewed_3d_signal
    return nil unless quote.active_for_signal?
    return nil unless quote.sent_at.present?
    return nil unless quote.view_count.zero?

    sent_days = days_since(quote.sent_at)
    return nil unless sent_days >= 3 && sent_days < 7

    signal(
      "not_viewed_3d",
      "watch",
      "resend_reminder",
      days_since_sent: sent_days
    )
  end

  def stalled_negotiation_signal
    return nil unless quote.status.to_s == "negotiating"
    return nil unless quote.updated_at.present?
    return nil unless quote.updated_at < 7.days.ago

    signal(
      "stalled_negotiation",
      "watch",
      "follow_up",
      stalled_days: days_since(quote.updated_at)
    )
  end

  def default_signal
    signal("default", "normal", "follow_up")
  end

  def signal(type, priority, action, metadata = {})
    QuoteSignal.new(
      type: type,
      priority: priority,
      recommended_action: action,
      label: I18n.t("signals.#{type}", default: I18n.t("signals.default")),
      cta_label: I18n.t("actions.#{action}", default: I18n.t("actions.follow_up")),
      metadata: metadata
    )
  end

  def customer_last_follow_up_before?(threshold_date)
    follow_up_date = quote.customer&.last_follow_up_date
    follow_up_date.blank? || follow_up_date < threshold_date
  end

  def days_since(time)
    return nil if time.blank?

    (Date.current - time.to_date).to_i
  end
end
