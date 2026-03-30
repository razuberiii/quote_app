class AddItemTypeToQuoteItems < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_items, :item_type, :string, null: false, default: "product_main"
    add_index :quote_items, [ :quote_id, :item_type, :created_at ]
  end
end
