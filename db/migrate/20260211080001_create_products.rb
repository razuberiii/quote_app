class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku, null: false
      t.text :description
      t.decimal :default_price, precision: 15, scale: 4, null: false

      t.timestamps
    end

    add_index :products, [ :company_id, :sku ], unique: true
  end
end
