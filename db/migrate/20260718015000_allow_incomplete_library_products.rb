class AllowIncompleteLibraryProducts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :products, :sku, true
    change_column_default :products, :default_price, from: nil, to: 0
  end
end
