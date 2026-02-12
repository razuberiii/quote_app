class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :company, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :quote_no
      t.integer :revision_number
      t.string :product_name
      t.decimal :unit_price, precision: 15, scale: 4
      t.integer :quantity
      t.string :currency
      t.date :valid_until
      t.string :payment_term
      t.string :status
      t.boolean :negotiated
      t.decimal :final_amount, precision: 15, scale: 4
      t.string :loss_reason
      t.text :notes

      t.timestamps
    end
  end
end
