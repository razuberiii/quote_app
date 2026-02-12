class AddCompanyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :company, null: true, foreign_key: true

    # Set a default company for existing users
    reversible do |dir|
      dir.up do
        # Create a default company for existing users without one
        execute <<-SQL
          INSERT INTO companies (created_at, updated_at)
          SELECT CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          WHERE NOT EXISTS (SELECT 1 FROM companies);

          UPDATE users SET company_id = (SELECT id FROM companies LIMIT 1)
          WHERE company_id IS NULL;
        SQL
      end
    end
  end
end
