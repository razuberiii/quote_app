class AddCrmFieldsToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :customer_level, :string, null: false, default: "normal"
    add_column :customers, :customer_source, :string
    add_column :customers, :payment_terms, :string
    add_column :customers, :main_product_interest, :string
    add_column :customers, :estimated_annual_volume, :decimal, precision: 15, scale: 2
    add_column :customers, :timezone, :string
    add_reference :customers, :internal_owner, foreign_key: { to_table: :users }
  end
end
