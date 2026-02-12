class MigrateQuotesToQuoteItems < ActiveRecord::Migration[8.1]
  def up
    # Create quote_items for each existing quote
    Quote.find_each do |quote|
      unless quote.quote_items.exists?
        # Only create if product_name exists (to avoid empty items)
        if quote.product_name.present?
          quote.quote_items.create!(
            description: quote.product_name,
            unit_price: quote.unit_price || 0,
            quantity: quote.quantity || 1,
            amount: (quote.unit_price || 0) * (quote.quantity || 1)
          )
        end
      end
    end
  end

  def down
    # Remove all quote items created during migration
    QuoteItem.destroy_all
  end
end
