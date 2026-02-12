class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name
      t.string :country
      t.string :contact_name
      t.string :email
      t.string :status
      t.date :next_follow_up_date
      t.date :last_follow_up_date
      t.text :notes

      t.timestamps
    end
  end
end
