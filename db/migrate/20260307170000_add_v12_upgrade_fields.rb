class AddV12UpgradeFields < ActiveRecord::Migration[8.1]
  def change
    change_table :products, bulk: true do |t|
      t.jsonb :default_specs, default: [], null: false
      t.jsonb :default_addons, default: [], null: false
      t.integer :quoted_count, default: 0, null: false
      t.integer :won_count, default: 0, null: false
      t.datetime :last_quoted_at
    end

    change_table :quote_items, bulk: true do |t|
      t.jsonb :spec_snapshot, default: [], null: false
      t.jsonb :addon_snapshot, default: [], null: false
    end

    change_table :quotes, bulk: true do |t|
      t.datetime :reminder_sent_at
      t.integer :reminder_count, default: 0, null: false
      t.string :request_reason
    end

    create_table :company_documents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title, null: false
      t.string :document_type, null: false

      t.timestamps
    end

    add_index :products, :quoted_count
    add_index :products, :won_count
    add_index :products, :last_quoted_at
    add_index :quotes, :reminder_sent_at
    add_index :quotes, :request_reason
    add_index :company_documents, [ :company_id, :document_type ]
  end
end
