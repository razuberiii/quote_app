class AddDefaultScopeOfSupplyContentToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_templates, :default_scope_of_supply_content, :text
  end
end
