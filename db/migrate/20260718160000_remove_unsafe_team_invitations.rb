class RemoveUnsafeTeamInvitations < ActiveRecord::Migration[8.1]
  def up
    drop_table :team_invitations
  end

  def down
    create_table :team_invitations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.integer :company_role, null: false, default: 1
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :team_invitations, :token, unique: true
    add_index :team_invitations, %i[company_id email accepted_at], name: "index_team_invites_on_company_email_status"
  end
end
