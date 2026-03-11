class CreateQuoteReasonOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_reason_options do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :key, null: false
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :quote_reason_options, [ :company_id, :kind, :key ], unique: true, name: "idx_quote_reason_options_company_kind_key"
    add_index :quote_reason_options, [ :company_id, :kind, :active, :position ], name: "idx_quote_reason_options_company_kind_order"
  end
end
