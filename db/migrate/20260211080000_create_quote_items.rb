class CreateQuoteItems < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.integer :product_id
      t.string :description, null: false
      t.decimal :unit_price, precision: 15, scale: 4, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :amount, precision: 15, scale: 4

      t.timestamps
    end

    add_index :quote_items, [ :quote_id, :created_at ]
  end
end
