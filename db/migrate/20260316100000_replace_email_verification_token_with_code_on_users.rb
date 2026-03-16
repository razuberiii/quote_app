class ReplaceEmailVerificationTokenWithCodeOnUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verification_code_digest, :string
    add_column :users, :email_verification_code_sent_at, :datetime
    add_column :users, :email_verification_attempts, :integer, null: false, default: 0

    remove_index :users, :email_verification_token, if_exists: true
    remove_column :users, :email_verification_token, :string
    remove_column :users, :email_verification_token_sent_at, :datetime
  end
end
