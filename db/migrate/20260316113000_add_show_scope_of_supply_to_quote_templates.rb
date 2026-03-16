class AddShowScopeOfSupplyToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :show_scope_of_supply, :boolean, null: false, default: false
  end
end
