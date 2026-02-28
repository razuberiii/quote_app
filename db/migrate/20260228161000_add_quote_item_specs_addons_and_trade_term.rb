class AddQuoteItemSpecsAddonsAndTradeTerm < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :trade_term, :string

    add_column :quote_items, :specifications, :jsonb, default: [], null: false
    add_column :quote_items, :addon_charges, :jsonb, default: [], null: false
  end
end
