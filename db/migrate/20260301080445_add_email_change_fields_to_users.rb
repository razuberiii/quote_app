class AddEmailChangeFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pending_email, :string
    add_column :users, :email_change_token, :string
    add_column :users, :email_change_sent_at, :datetime

    add_index :users, :email_change_token, unique: true
  end
end
