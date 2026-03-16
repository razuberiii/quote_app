class AddScopeOfSupplyToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :scope_of_supply, :text
  end
end
