class AddShippingPriceSourceToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :shipping_price_source, :string
  end
end
