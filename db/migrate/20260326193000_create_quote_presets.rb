class CreateQuotePresets < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_presets do |t|
      t.references :company, null: false, foreign_key: true
      t.string :module_key, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :quote_presets, [ :company_id, :module_key, :name ], unique: true, name: "idx_quote_presets_company_module_name"
    add_index :quote_presets, [ :company_id, :module_key, :active ], name: "idx_quote_presets_company_module_active"
  end
end
