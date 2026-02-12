class AddDocumentFieldsToCompaniesCustomersQuotes < ActiveRecord::Migration[8.1]
  def change
    change_table :companies, bulk: true do |t|
      t.string :address
      t.string :phone
      t.string :email
      t.string :website
    end

    change_table :customers, bulk: true do |t|
      t.string :address
      t.string :phone
    end

    change_table :quotes, bulk: true do |t|
      t.date :issued_on
      t.decimal :tax_amount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :shipping_amount, precision: 15, scale: 4, null: false, default: 0
      t.decimal :discount_amount, precision: 15, scale: 4, null: false, default: 0
      t.text :terms_text
      t.text :legal_disclaimer
      t.text :delivery_notes
    end
  end
end
