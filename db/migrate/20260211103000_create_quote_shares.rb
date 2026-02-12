class CreateQuoteShares < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_shares do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.string :token, null: false, index: { unique: true }
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :expires_at

      t.timestamps
    end
  end
end
