class CreateQuotePresetMasters < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_preset_masters do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: true
      t.references :business_terms_preset, null: true, foreign_key: { to_table: :quote_presets }
      t.references :advanced_trade_terms_preset, null: true, foreign_key: { to_table: :quote_presets }
      t.references :advanced_logistics_preset, null: true, foreign_key: { to_table: :quote_presets }
      t.references :container_loading_preset, null: true, foreign_key: { to_table: :quote_presets }
      t.references :configuration_block_preset, null: true, foreign_key: { to_table: :quote_presets }
      t.references :formal_closing_preset, null: true, foreign_key: { to_table: :quote_presets }

      t.timestamps
    end
  end
end
