class AddTaxIdToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :tax_id, :string
    add_column :customers, :tax_id_type, :string
  end
end
