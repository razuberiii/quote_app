class DealRadarService
  def initialize(quotes:, limit: 6)
    @quotes = quotes
    @limit = limit
  end

  def call
    @quotes
      .map { |quote| radar_item_for(quote) }
      .compact
      .sort_by { |item| [ QuoteSignalService.priority_rank(item[:signal].priority), -(item[:quote].updated_at || Time.zone.at(0)).to_i ] }
      .first(@limit)
  end

  def self.detail_for_signal(quote, signal)
    case signal.type
    when "hot_engagement_no_follow_up"
      I18n.t("signals.detail.hot_engagement_no_follow_up", count: quote.view_count)
    when "not_viewed_7d"
      I18n.t("signals.detail.not_viewed_7d", days: signal.metadata[:days_since_sent].to_i)
    when "not_viewed_3d"
      I18n.t("signals.detail.not_viewed_3d", days: signal.metadata[:days_since_sent].to_i)
    when "expiring_soon"
      I18n.t("signals.detail.expiring_soon", days: signal.metadata[:expires_in_days].to_i)
    when "revision_requested"
      I18n.t("signals.detail.revision_requested")
    when "viewed_no_follow_up"
      I18n.t("signals.detail.viewed_no_follow_up", count: quote.view_count)
    when "stalled_negotiation"
      I18n.t("signals.detail.stalled_negotiation", days: signal.metadata[:stalled_days].to_i)
    else
      I18n.t("signals.detail.default")
    end
  end

  private

  def radar_item_for(quote)
    signal = QuoteSignalService.new(quote).call
    return nil unless %w[urgent risk watch].include?(signal.priority)

    {
      quote: quote,
      signal: signal,
      detail: detail_for(quote, signal)
    }
  end

  def detail_for(quote, signal)
    self.class.detail_for_signal(quote, signal)
  end
end
