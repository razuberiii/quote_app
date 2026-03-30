class RevisionDepthAnalyticsService
  def initialize(company:)
    @company = company
  end

  # Returns win rate by revision depth.
  #
  # Considers all closed quote revisions (won/lost), not only latest revision per quote family.
  # Returns array sorted by revision_number:
  #
  # [
  #   { revision_number: 1, total: 40, wins: 17, win_rate: 42 },
  #   { revision_number: 2, total: 24, wins: 8,  win_rate: 33 },
  #   ...
  # ]
  def win_rate_by_revision
    rows = base_quotes
      .where(status: %w[won lost])
      .group(:revision_number)
      .select("revision_number, COUNT(*) AS total, SUM(CASE WHEN status = 'won' THEN 1 ELSE 0 END) AS wins")
      .order(:revision_number)
      .to_a

    rows.map do |row|
      total    = row.total.to_i
      wins     = row.wins.to_i
      win_rate = total.positive? ? ((wins.to_f / total) * 100).round : nil
      {
        revision_number: row.revision_number,
        total:           total,
        wins:            wins,
        win_rate:        win_rate
      }
    end
  end

  # Returns a simple distribution of all quote counts by revision_number (regardless of outcome).
  # { 1 => 58, 2 => 31, 3 => 12 }
  def revision_depth_distribution
    base_quotes
      .group(:revision_number)
      .count
      .sort
      .to_h
  end

  def base_quotes
    @base_quotes ||= Quote.where(company_id: @company.id).excluding_pi_documents
  end
end
