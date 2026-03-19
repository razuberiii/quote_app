class AddPositionToCustomerTaggings < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_taggings, :position, :integer, null: false, default: 0
    add_index :customer_taggings, [ :customer_id, :position ]
  end
end
