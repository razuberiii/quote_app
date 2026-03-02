class AddShowCustomerOwnerToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :show_customer_owner, :boolean, null: false, default: true
  end
end
