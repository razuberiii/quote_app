class AddCompanyRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :company_role, :integer, default: 2, null: false
    add_index :users, :company_role

    execute <<~SQL
      WITH ranked AS (
        SELECT id, company_id, ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY id ASC) AS rn
        FROM users
        WHERE company_id IS NOT NULL
      )
      UPDATE users
      SET company_role = 0
      FROM ranked
      WHERE users.id = ranked.id AND ranked.rn = 1
    SQL
  end

  def down
    remove_index :users, :company_role
    remove_column :users, :company_role
  end
end
