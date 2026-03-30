class QuoteFunnelReportService
  def initialize(company:)
    @company = company
  end

  def call
    latest_quotes = base_quotes.latest_versions.to_a
    sent_count = latest_quotes.count { |quote| quote.sent_at.present? }
    viewed_count = latest_quotes.count { |quote| quote.viewed_at.present? || quote.quote_shares.sum(&:view_count).positive? }
    revisions_count = revision_requested_count
    accepted_count = latest_quotes.count { |quote| quote.workflow_state == "accepted" }
    lost_count = latest_quotes.count { |quote| quote.workflow_state == "lost" }

    {
      quotes_sent: sent_count,
      quotes_viewed: viewed_count,
      revisions_requested: revisions_count,
      quotes_accepted: accepted_count,
      quotes_lost: lost_count,
      view_rate: rate(viewed_count, sent_count),
      revision_rate: rate(revisions_count, sent_count),
      acceptance_rate: rate(accepted_count, sent_count),
      loss_rate: rate(lost_count, sent_count)
    }
  end

  private

  def rate(numerator, denominator)
    return 0 if denominator.to_i <= 0

    ((numerator.to_f / denominator.to_f) * 100).round
  end

  def revision_requested_count
    families_with_multiple_revisions = base_quotes
      .group(:quote_no)
      .having("COUNT(*) > 1")
      .count
      .keys

    current_revision_requests = base_quotes
      .latest_versions
      .where.not(changes_requested_at: nil)
      .pluck(:quote_no)

    (families_with_multiple_revisions + current_revision_requests).uniq.count
  end

  def base_quotes
    @base_quotes ||= @company.quotes.not_archived.excluding_pi_documents
  end
end
