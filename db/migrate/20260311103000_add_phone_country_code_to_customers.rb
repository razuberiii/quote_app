class AddPhoneCountryCodeToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :phone_country_code, :string
  end
end
