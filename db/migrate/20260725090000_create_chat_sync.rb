class CreateChatSync < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_pairing_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :chat_pairing_codes, :code_digest, unique: true

    create_table :chat_sync_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.jsonb :scopes, default: [ "chat:sync" ], null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.string :label
      t.timestamps
    end
    add_index :chat_sync_tokens, :token_digest, unique: true

    create_table :chat_conversation_bindings do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.references :inquiry, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :platform_account_id, null: false
      t.string :platform_conversation_id, null: false
      t.string :display_name
      t.boolean :auto_analysis, default: true, null: false
      t.boolean :paused, default: false, null: false
      t.datetime :last_synced_at
      t.datetime :last_analyzed_at
      t.bigint :analyzed_message_cursor
      t.jsonb :analysis_result, default: {}, null: false
      t.timestamps
    end
    add_index :chat_conversation_bindings,
      %i[company_id platform platform_account_id platform_conversation_id],
      unique: true, name: "index_chat_bindings_on_platform_conversation"

    create_table :chat_sync_requests do |t|
      t.references :chat_conversation_binding, null: false, foreign_key: true
      t.string :request_id, null: false
      t.integer :accepted_count, default: 0, null: false
      t.timestamps
    end
    add_index :chat_sync_requests, %i[chat_conversation_binding_id request_id],
      unique: true, name: "index_chat_sync_requests_on_binding_and_request"

    create_table :chat_captured_messages do |t|
      t.references :chat_conversation_binding, null: false, foreign_key: true
      t.references :inquiry_message, foreign_key: true
      t.string :local_id, null: false
      t.string :platform_message_id
      t.string :fingerprint, null: false
      t.string :direction, null: false
      t.string :sender_id
      t.string :sender_name
      t.datetime :sent_at
      t.datetime :captured_at, null: false
      t.string :message_type, null: false
      t.text :text
      t.text :quoted_text
      t.string :attachment_name
      t.jsonb :source_metadata, default: {}, null: false
      t.string :parser_version, null: false
      t.timestamps
    end
    add_index :chat_captured_messages, %i[chat_conversation_binding_id fingerprint],
      unique: true, name: "index_chat_messages_on_binding_and_fingerprint"
  end
end
