class AddSettingsFieldsToUsersAndCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :full_name, :string
    add_column :users, :contact_phone, :string
    add_column :users, :job_title, :string
    add_column :users, :time_zone, :string
    add_column :users, :language, :string

    add_column :companies, :legal_name, :string
    add_column :companies, :registration_number, :string
    add_column :companies, :registration_details, :text
    add_column :companies, :default_currency, :string, default: "USD"
    add_column :companies, :default_trade_term, :string
    add_column :companies, :default_payment_term, :string
    add_column :companies, :default_tax_rate, :decimal, precision: 6, scale: 2, default: 0, null: false
    add_column :companies, :default_validity_days, :integer, default: 30, null: false
    add_column :companies, :brand_color, :string, default: "#1F4E79"
  end
end
