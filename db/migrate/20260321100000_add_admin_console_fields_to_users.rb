class AddAdminConsoleFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :status, :integer, default: 0, null: false
    add_column :users, :last_login_at, :datetime
    add_column :users, :last_active_at, :datetime

    add_index :users, :status
    add_index :users, :last_active_at
  end
end
