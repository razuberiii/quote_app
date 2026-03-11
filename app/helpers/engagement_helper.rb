module EngagementHelper
  def engagement_badge(quote)
    score = quote.engagement_score
    label = quote.engagement_label
    score_text = t("engagement.points", count: score)

    case label
    when :hot
      tag.span(
        "🔥 #{t("engagement.hot")} • #{score_text}",
        class: "badge badge-success"
      )
    when :warm
      tag.span(
        "🌤 #{t("engagement.warm")} • #{score_text}",
        class: "badge badge-warning"
      )
    else  # cold
      tag.span(
        "❄️ #{t("engagement.cold")} • #{score_text}",
        class: "badge badge-secondary"
      )
    end
  end

  def quote_engagement_stats(quote)
    avg_seconds = quote.avg_view_duration_seconds.to_i
    avg_time =
      if avg_seconds.positive?
        minutes = avg_seconds / 60
        seconds = avg_seconds % 60
        format("%<minutes>dm %<seconds>ds", minutes: minutes, seconds: seconds)
      else
        I18n.t("engagement.panel.not_available")
      end

    {
      views: quote.view_count,
      revisions: quote.revision_requests_count,
      avg_time: avg_time,
      score: quote.engagement_score
    }
  end

  def average_product_price(product)
    avg = QuoteItem
      .joins(:quote)
      .where(product_id: product.id)
      .average(:unit_price)
      &.round(2)
    avg.present? ? number_to_currency(avg) : "N/A"
  end

  def recent_product_quotes(product, limit: 5)
    QuoteItem
      .joins(:quote)
      .where(product_id: product.id)
      .select("DISTINCT ON (quote_id) quotes.*, quote_items.unit_price")
      .order("quote_id DESC")
      .limit(limit)
  end
end
