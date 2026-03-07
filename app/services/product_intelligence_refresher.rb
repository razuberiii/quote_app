class ProductIntelligenceRefresher
  class << self
    def refresh_for_quote(quote)
      refresh_products(quote.quote_items.where.not(product_id: nil).distinct.pluck(:product_id))
    end

    def refresh_products(product_ids)
      Array(product_ids).compact.uniq.each do |product_id|
        refresh_product(product_id)
      end
    end

    def refresh_product(product_id)
      product = Product.find_by(id: product_id)
      return if product.blank?

      scoped_items = QuoteItem.joins(:quote)
        .where(product_id: product.id, quotes: { company_id: product.company_id })
        .where(quotes: { archived_at: nil, deleted_at: nil })

      quoted_count = scoped_items.distinct.count("quotes.quote_no")
      won_count = scoped_items.where(quotes: { status: "won" }).distinct.count("quotes.quote_no")
      last_quoted_at = scoped_items.maximum(:created_at)

      product.update_columns(
        quoted_count: quoted_count,
        won_count: won_count,
        last_quoted_at: last_quoted_at,
        updated_at: Time.current
      )
    end
  end
end
