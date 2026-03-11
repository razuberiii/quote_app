class ProductQuoteAnalyticsService
  DEFAULT_PERIOD_DAYS = 30

  def initialize(company:, period_days: DEFAULT_PERIOD_DAYS)
    @company    = company
    @period_days = period_days
  end

  # Returns aggregated stats for a single product.
  #
  # Returns:
  #   {
  #     quotes_count: 28,
  #     wins_count:   9,
  #     avg_price:    118.50,  # BigDecimal or nil
  #     win_rate:     32       # integer percentage, or nil if no quotes
  #   }
  def product_stats(product_id)
    base = QuoteItem
      .with_product
      .joins(:quote)
      .where(product_id: product_id)
      .where(quotes: { company_id: @company.id })
      .in_period(@period_days)

    quotes_count = base.count
    wins_count   = base.where(quotes: { status: "won" }).count
    avg_price    = base.average(:unit_price)&.round(2)
    win_rate     = quotes_count.positive? ? ((wins_count.to_f / quotes_count) * 100).round : nil

    { quotes_count: quotes_count, wins_count: wins_count, avg_price: avg_price, win_rate: win_rate }
  end

  # Returns stats for the top N most-quoted products in the company within the period.
  #
  # Returns array of { product_id:, product_name:, **stats }
  def top_products(limit: 10)
    rows = QuoteItem
      .with_product
      .joins(:quote, :product)
      .where(quotes: { company_id: @company.id })
      .in_period(@period_days)
      .group("quote_items.product_id, products.name")
      .select("product_id, products.name AS product_name, COUNT(*) AS quotes_count, SUM(CASE WHEN quotes.status = 'won' THEN 1 ELSE 0 END) AS wins_count, AVG(quote_items.unit_price) AS avg_price")
      .order("quotes_count DESC")
      .limit(limit)

    rows.map do |row|
      win_rate = row.quotes_count.positive? ? ((row.wins_count.to_f / row.quotes_count) * 100).round : nil
      {
        product_id:   row.product_id,
        product_name: row.product_name,
        quotes_count: row.quotes_count,
        wins_count:   row.wins_count,
        avg_price:    row.avg_price&.round(2),
        win_rate:     win_rate
      }
    end
  end
end
