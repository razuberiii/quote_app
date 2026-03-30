class DashboardPerformanceReportService
  OPEN_WORKFLOW_STATES = %w[draft sent viewed negotiating].freeze

  def initialize(customers:)
    @customers = Array(customers)
  end

  def call
    customer_rows = @customers.filter_map { |customer| build_customer_row(customer) }

    {
      sales_ownership: build_owner_rows(customer_rows).first(5),
      customer_portfolio: customer_rows.sort_by { |row| customer_sort_key(row) }.first(5)
    }
  end

  private

  def build_customer_row(customer)
    latest_quotes = latest_quotes_for(customer)
    return nil if latest_quotes.empty?

    won_quotes = latest_quotes.count { |quote| quote.workflow_state == "accepted" }
    open_quotes = latest_quotes.count { |quote| OPEN_WORKFLOW_STATES.include?(quote.workflow_state) }
    quote_threads = latest_quotes.size
    last_quote_at = latest_quotes.map(&:updated_at).compact.max

    {
      customer: customer,
      name: customer.name,
      owner_name: customer.internal_owner_display_name.presence == "-" ? "Unassigned" : customer.internal_owner_display_name,
      quote_threads: quote_threads,
      won_quotes: won_quotes,
      open_quotes: open_quotes,
      win_rate: quote_threads.positive? ? ((won_quotes.to_f / quote_threads.to_f) * 100).round : 0,
      last_quote_at: last_quote_at,
      overdue_follow_up: customer.follow_up_overdue?
    }
  end

  def build_owner_rows(customer_rows)
    customer_rows
      .group_by { |row| row[:owner_name].presence || "Unassigned" }
      .map do |owner_name, rows|
        {
          owner_name: owner_name,
          account_count: rows.size,
          quote_threads: rows.sum { |row| row[:quote_threads] },
          won_quotes: rows.sum { |row| row[:won_quotes] },
          open_quotes: rows.sum { |row| row[:open_quotes] },
          overdue_accounts: rows.count { |row| row[:overdue_follow_up] },
          win_rate: owner_win_rate(rows),
          last_quote_at: rows.map { |row| row[:last_quote_at] }.compact.max
        }
      end
      .sort_by { |row| owner_sort_key(row) }
  end

  def owner_win_rate(rows)
    total_threads = rows.sum { |row| row[:quote_threads] }
    return 0 if total_threads <= 0

    ((rows.sum { |row| row[:won_quotes] }.to_f / total_threads.to_f) * 100).round
  end

  def latest_quotes_for(customer)
    customer.quotes
      .reject { |quote| archived_or_deleted?(quote) || quote.pi_document? }
      .group_by(&:quote_no)
      .values
      .map { |revisions| revisions.max_by(&:revision_number) }
  end

  def archived_or_deleted?(quote)
    (quote.respond_to?(:archived?) && quote.archived?) ||
      (quote.respond_to?(:deleted?) && quote.deleted?)
  end

  def customer_sort_key(row)
    [
      -row[:won_quotes].to_i,
      -row[:open_quotes].to_i,
      -row[:quote_threads].to_i,
      -(row[:last_quote_at]&.to_i || 0)
    ]
  end

  def owner_sort_key(row)
    [
      -row[:won_quotes].to_i,
      -row[:open_quotes].to_i,
      -row[:quote_threads].to_i,
      row[:overdue_accounts].to_i,
      -(row[:last_quote_at]&.to_i || 0)
    ]
  end
end
