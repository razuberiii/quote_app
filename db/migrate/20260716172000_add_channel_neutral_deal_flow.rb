class AddChannelNeutralDealFlow < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_revisions, :published_at, :datetime

    create_table :version_deliveries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :channel, null: false
      t.string :recipient
      t.string :status, null: false, default: "succeeded"
      t.string :external_channel
      t.text :note
      t.datetime :delivered_at, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :version_deliveries, [ :quote_revision_id, :idempotency_key ], unique: true,
      name: "idx_version_deliveries_idempotency"

    create_table :deal_responses do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :source, null: false
      t.string :buyer_name
      t.string :buyer_email
      t.string :context_type, null: false, default: "quote"
      t.string :context_key
      t.text :body
      t.string :status, null: false, default: "open"
      t.jsonb :extracted_changes, null: false, default: {}
      t.jsonb :difference_review, null: false, default: {}
      t.datetime :received_at, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :deal_responses, [ :quote_id, :idempotency_key ], unique: true,
      name: "idx_deal_responses_idempotency"

    change_table :quote_acceptances, bulk: true do |t|
      t.string :acceptance_method, null: false, default: "buyer_room"
      t.string :buyer_company
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.boolean :seller_recorded, null: false, default: false
      t.boolean :has_differences, null: false, default: false
      t.jsonb :difference_review, null: false, default: {}
      t.string :evidence_summary
    end

    create_table :final_documents do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_acceptance, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :document_type, null: false
      t.string :title, null: false
      t.string :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :currency, null: false
      t.decimal :total, precision: 15, scale: 4, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :sent_at
      t.timestamps
    end
    add_index :final_documents, [ :company_id, :number ], unique: true

    change_table :companies, bulk: true do |t|
      t.string :default_final_document_type, null: false, default: "order_confirmation"
      t.boolean :require_final_document, null: false, default: false
      t.boolean :require_deposit_workflow, null: false, default: false
    end
  end
end
