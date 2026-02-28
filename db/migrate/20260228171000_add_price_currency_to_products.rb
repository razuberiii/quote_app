class AddPriceCurrencyToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :price_currency, :string, null: false, default: "USD"
  end
end
