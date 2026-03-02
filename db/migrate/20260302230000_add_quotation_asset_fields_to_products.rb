class AddQuotationAssetFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :cost_price, :decimal, precision: 15, scale: 4
    add_column :products, :unit, :string
    add_column :products, :moq, :integer
    add_column :products, :lead_time, :string
    add_column :products, :product_category, :string
    add_column :products, :default_specification, :text
  end
end
