class CreateRubusooCommercialCore < ActiveRecord::Migration[8.1]
  def change
    change_table :companies, bulk: true do |t|
      t.string :slug
      t.string :business_type
      t.string :plan, null: false, default: "trial"
      t.datetime :trial_ends_at
      t.string :subscription_status, null: false, default: "trialing"
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :quote_language, null: false, default: "en"
    end
    add_index :companies, :slug, unique: true
    add_index :companies, :stripe_customer_id, unique: true, where: "stripe_customer_id IS NOT NULL"

    change_table :quotes, bulk: true do |t|
      t.string :next_action
      t.date :follow_up_on
      t.text :internal_note
      t.string :language, null: false, default: "en"
      t.string :studio_state, null: false, default: "draft"
    end

    create_table :quote_revisions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.integer :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :currency, null: false
      t.decimal :total, precision: 15, scale: 4, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.jsonb :diff, null: false, default: {}
      t.text :summary
      t.string :secure_token, null: false
      t.datetime :sent_at
      t.datetime :revoked_at
      t.datetime :superseded_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :quote_revisions, [:quote_id, :number], unique: true
    add_index :quote_revisions, :secure_token, unique: true
    add_index :quote_revisions, [:quote_id, :status]

    create_table :buyer_questions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.string :context_type, null: false, default: "quote"
      t.string :context_key
      t.string :buyer_name
      t.string :buyer_email
      t.text :body, null: false
      t.text :seller_reply
      t.datetime :replied_at
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :buyer_questions, [:quote_revision_id, :idempotency_key], unique: true, name: "idx_buyer_questions_idempotency"

    create_table :change_requests do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true
      t.string :buyer_name
      t.string :buyer_email
      t.text :message, null: false
      t.jsonb :requested_changes, null: false, default: {}
      t.string :status, null: false, default: "open"
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :change_requests, [:quote_revision_id, :idempotency_key], unique: true, name: "idx_change_requests_idempotency"

    create_table :quote_acceptances do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :email, null: false
      t.string :job_title
      t.string :po_number
      t.text :note
      t.jsonb :selection, null: false, default: {}
      t.jsonb :snapshot, null: false, default: {}
      t.decimal :total, precision: 15, scale: 4, null: false
      t.string :currency, null: false
      t.string :idempotency_key, null: false
      t.datetime :accepted_at, null: false
      t.timestamps
    end
    add_index :quote_acceptances, [:quote_id, :idempotency_key], unique: true, name: "idx_quote_acceptances_idempotency"

    create_table :proforma_invoices do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_acceptance, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :number, null: false
      t.string :status, null: false, default: "awaiting_deposit"
      t.string :currency, null: false
      t.decimal :total, precision: 15, scale: 4, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :sent_at
      t.datetime :deposit_received_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :proforma_invoices, [:company_id, :number], unique: true

    create_table :buyer_activities do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.references :quote_revision, foreign_key: true
      t.string :kind, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :deduplication_key, null: false
      t.timestamps
    end
    add_index :buyer_activities, [:company_id, :deduplication_key], unique: true, name: "idx_buyer_activities_dedup"

    create_table :inquiries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.text :source_text
      t.string :source_type, null: false, default: "manual"
      t.string :status, null: false, default: "draft"
      t.jsonb :extracted_data, null: false, default: {}
      t.jsonb :field_states, null: false, default: {}
      t.timestamps
    end

    create_table :subscription_events do |t|
      t.references :company, null: false, foreign_key: true
      t.string :provider_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.timestamps
    end
    add_index :subscription_events, :provider_event_id, unique: true
  end
end
