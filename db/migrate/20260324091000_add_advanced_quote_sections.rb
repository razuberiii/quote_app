class AddAdvancedQuoteSections < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :advanced_mode, :boolean, default: false, null: false
    add_column :quotes, :advanced_trade_terms, :jsonb, default: {}, null: false
    add_column :quotes, :advanced_logistics, :jsonb, default: {}, null: false
    add_column :quotes, :advanced_visibility, :jsonb, default: {}, null: false

    add_column :quote_templates, :enable_advanced_by_default, :boolean, default: false, null: false
    add_column :quote_templates, :advanced_defaults, :jsonb, default: {}, null: false
    add_column :quote_templates, :advanced_visibility_defaults, :jsonb, default: {}, null: false
  end
end
