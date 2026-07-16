class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string
    execute <<~SQL
      UPDATE users
      SET username = LOWER(REGEXP_REPLACE(SPLIT_PART(email, '@', 1), '[^a-zA-Z0-9_]', '_', 'g')) || '_' || id
      WHERE username IS NULL
    SQL
    change_column_null :users, :username, false
    add_index :users, "LOWER(username)", unique: true, name: "index_users_on_lower_username"
  end

  def down
    remove_index :users, name: "index_users_on_lower_username"
    remove_column :users, :username
  end
end
