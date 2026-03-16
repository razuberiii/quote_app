class AddScopeOfSupplyLabelToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :scope_of_supply_label, :string
  end
end
