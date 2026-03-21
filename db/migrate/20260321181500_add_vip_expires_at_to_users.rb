class AddVipExpiresAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :vip_expires_at, :datetime
    add_index :users, :vip_expires_at
  end
end
