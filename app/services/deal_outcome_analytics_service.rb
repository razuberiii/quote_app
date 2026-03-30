class DealOutcomeAnalyticsService
  def initialize(company:)
    @company = company
  end

  # Returns win reason distribution as { reason_key => count }, sorted descending.
  # Example: { "price_accepted" => 14, "buyer_relationship" => 9, "other" => 3 }
  def win_reason_distribution
    base_quotes
      .where(status: "won")
      .pluck(:win_reason)
      .each_with_object(Hash.new(0)) { |reason, memo| memo[normalize_reason_key(reason)] += 1 }
      .sort_by { |_k, v| -v }
      .to_h
  end

  # Returns loss reason distribution as { reason_key => count }, sorted descending.
  def loss_reason_distribution
    base_quotes
      .where(status: "lost")
      .pluck(:loss_reason)
      .each_with_object(Hash.new(0)) { |reason, memo| memo[normalize_reason_key(reason)] += 1 }
      .sort_by { |_k, v| -v }
      .to_h
  end

  # Returns free-text breakdown for "other" loss reasons.
  # Trims, downcases, groups by normalized text → count.
  # Returns [] if none.
  def loss_other_breakdown(limit: 20)
    base_quotes
      .where(status: "lost", loss_reason: "other")
      .where.not(loss_reason_detail: [ nil, "" ])
      .pluck(:loss_reason_detail)
      .each_with_object(Hash.new(0)) do |detail, memo|
        normalized = normalize_other_detail(detail)
        memo[normalized] += 1 if normalized.present?
      end
      .sort_by { |_k, v| -v }
      .first(limit)
      .to_h
  end

  # Combined summary for templating — returns view-ready arrays with percentage labels:
  # {
  #   win_reasons:        [{ label:, count:, pct: }, ...],
  #   loss_reasons:       [{ label:, count:, pct: }, ...],
  #   loss_other_details: [{ detail:, count: }, ...]
  # }
  def summary
    win_dist  = win_reason_distribution
    loss_dist = loss_reason_distribution
    other     = loss_other_breakdown

    win_total  = win_dist.values.sum
    loss_total = loss_dist.values.sum

    win_reasons = win_dist.map do |reason, count|
      { label: localized_reason_label(reason, category: :win), count: count, pct: win_total.zero? ? 0 : ((count.to_f / win_total) * 100).round }
    end

    loss_reasons = loss_dist.map do |reason, count|
      { label: localized_reason_label(reason, category: :loss), count: count, pct: loss_total.zero? ? 0 : ((count.to_f / loss_total) * 100).round }
    end

    {
      win_reasons:        win_reasons,
      loss_reasons:       loss_reasons,
      loss_other_details: other.map { |detail, count| { detail: detail, count: count } }
    }
  end

  private

  def localized_reason_label(reason, category:)
    custom_label = Quote.reason_label_for(category, reason, company: @company)
    return custom_label if custom_label.present?

    key = "analytics.reason_labels.#{category}.#{reason}"
    I18n.t(key, default: fallback_reason_label(reason))
  end

  def normalize_reason_key(reason)
    reason.to_s.squish.presence || "unspecified"
  end

  def normalize_other_detail(detail)
    cleaned = detail.to_s.squish.downcase
    return nil if cleaned.blank?

    # Avoid exposing low-signal entries like pure numbers/codes in the UI.
    return I18n.t("analytics.win_loss_distribution.other_unstructured") unless cleaned.match?(/\p{L}/u)

    cleaned
  end

  def fallback_reason_label(reason)
    reason.to_s.tr("_", " ").squish.humanize
  end

  def base_quotes
    @base_quotes ||= Quote.where(company_id: @company.id).excluding_pi_documents
  end
end
