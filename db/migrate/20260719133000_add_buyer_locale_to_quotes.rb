class AddBuyerLocaleToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :buyer_locale, :string, null: false, default: "en"
  end
end
