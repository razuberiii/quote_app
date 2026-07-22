# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_19_133000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_items", force: :cascade do |t|
    t.string "action_type", null: false
    t.datetime "created_at", null: false
    t.bigint "reference_id", null: false
    t.string "reference_type", null: false
    t.datetime "resolved_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["reference_type", "reference_id"], name: "index_action_items_on_reference_type_and_reference_id"
    t.index ["user_id", "action_type", "reference_type", "reference_id"], name: "index_action_items_on_user_action_reference"
    t.index ["user_id", "resolved_at"], name: "index_action_items_on_user_id_and_resolved_at"
    t.index ["user_id"], name: "index_action_items_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addon_presets", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "entries", default: [], null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_addon_presets_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_addon_presets_on_company_id"
  end

  create_table "ai_analyses", force: :cascade do |t|
    t.jsonb "accepted_fields", default: [], null: false
    t.string "analysis_type", null: false
    t.bigint "company_id", null: false
    t.jsonb "corrected_fields", default: {}, null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_cost", precision: 12, scale: 6
    t.string "input_fingerprint", null: false
    t.integer "input_tokens"
    t.integer "latency_ms"
    t.string "model", null: false
    t.integer "output_tokens"
    t.string "provider", null: false
    t.jsonb "raw_json", default: {}, null: false
    t.jsonb "rejected_fields", default: [], null: false
    t.string "schema_version", null: false
    t.bigint "source_record_id", null: false
    t.string "source_record_type", null: false
    t.string "status", default: "validated", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_result", default: {}, null: false
    t.index ["company_id", "analysis_type", "input_fingerprint"], name: "idx_ai_analysis_fingerprint"
    t.index ["company_id"], name: "index_ai_analyses_on_company_id"
    t.index ["source_record_type", "source_record_id"], name: "index_ai_analyses_on_source_record"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
  end

  create_table "buyer_activities", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "deduplication_key", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "quote_id", null: false
    t.bigint "quote_revision_id"
    t.datetime "updated_at", null: false
    t.index ["company_id", "deduplication_key"], name: "idx_buyer_activities_dedup", unique: true
    t.index ["company_id"], name: "index_buyer_activities_on_company_id"
    t.index ["quote_id"], name: "index_buyer_activities_on_quote_id"
    t.index ["quote_revision_id"], name: "index_buyer_activities_on_quote_revision_id"
  end

  create_table "buyer_questions", force: :cascade do |t|
    t.text "body", null: false
    t.string "buyer_email"
    t.string "buyer_name"
    t.bigint "company_id", null: false
    t.string "context_key"
    t.string "context_type", default: "quote", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.bigint "quote_revision_id", null: false
    t.datetime "replied_at"
    t.text "seller_reply"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_buyer_questions_on_company_id"
    t.index ["quote_revision_id", "idempotency_key"], name: "idx_buyer_questions_idempotency", unique: true
    t.index ["quote_revision_id"], name: "index_buyer_questions_on_quote_revision_id"
  end

  create_table "change_requests", force: :cascade do |t|
    t.string "buyer_email"
    t.string "buyer_name"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.text "message", null: false
    t.bigint "quote_revision_id", null: false
    t.jsonb "requested_changes", default: {}, null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_change_requests_on_company_id"
    t.index ["quote_revision_id", "idempotency_key"], name: "idx_change_requests_idempotency", unique: true
    t.index ["quote_revision_id"], name: "index_change_requests_on_quote_revision_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "address"
    t.string "brand_color", default: "#1F4E79"
    t.string "business_type"
    t.datetime "created_at", null: false
    t.string "default_currency", default: "USD"
    t.string "default_final_document_type", default: "order_confirmation", null: false
    t.string "default_payment_term"
    t.decimal "default_tax_rate", precision: 6, scale: 2, default: "0.0", null: false
    t.string "default_trade_term"
    t.integer "default_validity_days", default: 30, null: false
    t.string "email"
    t.string "legal_name"
    t.string "name"
    t.string "phone"
    t.string "plan", default: "trial", null: false
    t.string "quote_language", default: "zh-CN", null: false
    t.text "registration_details"
    t.string "registration_number"
    t.text "reminder_email_body"
    t.string "reminder_email_cta_label"
    t.string "reminder_email_subject"
    t.boolean "require_deposit_workflow", default: false, null: false
    t.boolean "require_final_document", default: false, null: false
    t.string "slug"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status", default: "trialing", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["slug"], name: "index_companies_on_slug", unique: true
    t.index ["stripe_customer_id"], name: "index_companies_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
  end

  create_table "company_documents", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "document_type", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "document_type"], name: "index_company_documents_on_company_id_and_document_type"
    t.index ["company_id"], name: "index_company_documents_on_company_id"
  end

  create_table "company_profile_imports", force: :cascade do |t|
    t.jsonb "candidate_data", default: {}, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "source_text"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.jsonb "warnings", default: [], null: false
    t.index ["company_id", "status"], name: "index_company_profile_imports_on_company_id_and_status"
    t.index ["company_id"], name: "index_company_profile_imports_on_company_id"
    t.index ["created_by_id"], name: "index_company_profile_imports_on_created_by_id"
  end

  create_table "customer_follow_up_events", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "contacted_at", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "note"
    t.bigint "quote_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["channel"], name: "index_customer_follow_up_events_on_channel"
    t.index ["customer_id", "contacted_at"], name: "index_customer_follow_up_events_on_customer_and_contacted_at"
    t.index ["customer_id"], name: "index_customer_follow_up_events_on_customer_id"
    t.index ["quote_id"], name: "index_customer_follow_up_events_on_quote_id"
    t.index ["user_id"], name: "index_customer_follow_up_events_on_user_id"
  end

  create_table "customer_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "customer_tag_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "customer_tag_id"], name: "index_customer_taggings_on_customer_id_and_customer_tag_id", unique: true
    t.index ["customer_id", "position"], name: "index_customer_taggings_on_customer_id_and_position"
    t.index ["customer_id"], name: "index_customer_taggings_on_customer_id"
    t.index ["customer_tag_id"], name: "index_customer_taggings_on_customer_tag_id"
  end

  create_table "customer_tags", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_customer_tags_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_customer_tags_on_company_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.bigint "company_id", null: false
    t.string "contact_name"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "customer_level", default: "normal", null: false
    t.string "customer_source"
    t.string "email"
    t.string "engagement_state", default: "unassessed", null: false
    t.decimal "estimated_annual_volume", precision: 15, scale: 2
    t.bigint "internal_owner_id"
    t.date "last_follow_up_date"
    t.string "main_product_interest"
    t.boolean "manual_engagement_override", default: false, null: false
    t.string "name"
    t.date "next_follow_up_date"
    t.text "notes"
    t.string "payment_terms"
    t.string "phone"
    t.string "phone_country_code"
    t.string "status"
    t.string "tax_id"
    t.string "tax_id_type"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_customers_on_company_id"
    t.index ["engagement_state"], name: "index_customers_on_engagement_state"
    t.index ["internal_owner_id"], name: "index_customers_on_internal_owner_id"
    t.index ["manual_engagement_override"], name: "index_customers_on_manual_engagement_override"
  end

  create_table "deal_responses", force: :cascade do |t|
    t.text "body"
    t.string "buyer_email"
    t.string "buyer_name"
    t.bigint "company_id", null: false
    t.string "context_key"
    t.string "context_type", default: "quote", null: false
    t.datetime "created_at", null: false
    t.jsonb "difference_review", default: {}, null: false
    t.jsonb "extracted_changes", default: {}, null: false
    t.string "idempotency_key", null: false
    t.string "kind", null: false
    t.bigint "quote_id", null: false
    t.bigint "quote_revision_id", null: false
    t.datetime "received_at", null: false
    t.bigint "recorded_by_id"
    t.string "source", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_deal_responses_on_company_id"
    t.index ["quote_id", "idempotency_key"], name: "idx_deal_responses_idempotency", unique: true
    t.index ["quote_id"], name: "index_deal_responses_on_quote_id"
    t.index ["quote_revision_id"], name: "index_deal_responses_on_quote_revision_id"
    t.index ["recorded_by_id"], name: "index_deal_responses_on_recorded_by_id"
  end

  create_table "evidence_records", force: :cascade do |t|
    t.bigint "ai_analysis_id"
    t.bigint "company_id", null: false
    t.decimal "confidence", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.string "evidence_key", null: false
    t.text "excerpt", null: false
    t.string "field_path"
    t.jsonb "locator", default: {}, null: false
    t.bigint "source_record_id", null: false
    t.string "source_record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_analysis_id"], name: "index_evidence_records_on_ai_analysis_id"
    t.index ["company_id"], name: "index_evidence_records_on_company_id"
    t.index ["source_record_type", "source_record_id"], name: "index_evidence_records_on_source_record"
  end

  create_table "final_documents", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", null: false
    t.string "document_type", null: false
    t.text "error_message"
    t.string "file_name"
    t.bigint "file_size"
    t.datetime "generated_at"
    t.string "number", null: false
    t.text "payment_note"
    t.datetime "payment_received_at"
    t.bigint "quote_acceptance_id", null: false
    t.bigint "quote_id", null: false
    t.datetime "sent_at"
    t.jsonb "snapshot", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.decimal "total", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "number"], name: "index_final_documents_on_company_id_and_number", unique: true
    t.index ["company_id"], name: "index_final_documents_on_company_id"
    t.index ["created_by_id"], name: "index_final_documents_on_created_by_id"
    t.index ["quote_acceptance_id"], name: "index_final_documents_on_quote_acceptance_id"
    t.index ["quote_id"], name: "index_final_documents_on_quote_id"
  end

  create_table "inquiries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "customer_id"
    t.jsonb "extracted_data", default: {}, null: false
    t.jsonb "field_states", default: {}, null: false
    t.text "source_text"
    t.string "source_type", default: "manual", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_inquiries_on_company_id"
    t.index ["created_by_id"], name: "index_inquiries_on_created_by_id"
    t.index ["customer_id"], name: "index_inquiries_on_customer_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, comment: "Contextual data: quote_id, quote_no, customer_name, etc"
    t.datetime "dismissed_at", comment: "When user dismissed the notification"
    t.string "kind", null: false, comment: "Type of notification: quote_viewed, etc"
    t.datetime "read_at", comment: "When user read the notification"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "product_addon_presets", force: :cascade do |t|
    t.bigint "addon_preset_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["addon_preset_id"], name: "index_product_addon_presets_on_addon_preset_id"
    t.index ["product_id", "addon_preset_id"], name: "index_product_addon_presets_on_product_id_and_addon_preset_id", unique: true
    t.index ["product_id"], name: "index_product_addon_presets_on_product_id"
  end

  create_table "product_import_batches", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "input_fingerprint", null: false
    t.jsonb "processing_report", default: [], null: false
    t.string "status", default: "review", null: false
    t.datetime "updated_at", null: false
    t.jsonb "warnings", default: [], null: false
    t.index ["company_id"], name: "index_product_import_batches_on_company_id"
    t.index ["created_by_id"], name: "index_product_import_batches_on_created_by_id"
  end

  create_table "product_import_candidates", force: :cascade do |t|
    t.jsonb "candidate_data", default: {}, null: false
    t.decimal "confidence", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.string "decision", default: "pending", null: false
    t.jsonb "evidence", default: [], null: false
    t.bigint "matched_product_id"
    t.bigint "product_import_batch_id", null: false
    t.datetime "updated_at", null: false
    t.index ["matched_product_id"], name: "index_product_import_candidates_on_matched_product_id"
    t.index ["product_import_batch_id"], name: "index_product_import_candidates_on_product_import_batch_id"
  end

  create_table "product_spec_presets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "spec_preset_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "spec_preset_id"], name: "index_product_spec_presets_on_product_id_and_spec_preset_id", unique: true
    t.index ["product_id"], name: "index_product_spec_presets_on_product_id"
    t.index ["spec_preset_id"], name: "index_product_spec_presets_on_spec_preset_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.decimal "cost_price", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.bigint "default_addon_preset_id"
    t.jsonb "default_addons", default: [], null: false
    t.decimal "default_price", precision: 15, scale: 4
    t.bigint "default_spec_preset_id"
    t.text "default_specification"
    t.jsonb "default_specs", default: [], null: false
    t.text "description"
    t.datetime "last_quoted_at"
    t.string "lead_time"
    t.integer "moq"
    t.string "name", null: false
    t.string "price_currency", default: "USD", null: false
    t.string "product_category"
    t.integer "quoted_count", default: 0, null: false
    t.string "sku"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.integer "won_count", default: 0, null: false
    t.index ["company_id", "sku"], name: "index_products_on_company_id_and_sku", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
    t.index ["default_addon_preset_id"], name: "index_products_on_default_addon_preset_id"
    t.index ["default_spec_preset_id"], name: "index_products_on_default_spec_preset_id"
    t.index ["last_quoted_at"], name: "index_products_on_last_quoted_at"
    t.index ["quoted_count"], name: "index_products_on_quoted_count"
    t.index ["won_count"], name: "index_products_on_won_count"
  end

  create_table "proforma_invoices", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", null: false
    t.datetime "deposit_received_at"
    t.string "number", null: false
    t.bigint "quote_acceptance_id", null: false
    t.bigint "quote_id", null: false
    t.datetime "sent_at"
    t.jsonb "snapshot", default: {}, null: false
    t.string "status", default: "awaiting_deposit", null: false
    t.decimal "total", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "number"], name: "index_proforma_invoices_on_company_id_and_number", unique: true
    t.index ["company_id"], name: "index_proforma_invoices_on_company_id"
    t.index ["created_by_id"], name: "index_proforma_invoices_on_created_by_id"
    t.index ["quote_acceptance_id"], name: "index_proforma_invoices_on_quote_acceptance_id", unique: true
    t.index ["quote_id"], name: "index_proforma_invoices_on_quote_id"
  end

  create_table "quote_acceptances", force: :cascade do |t|
    t.string "acceptance_method", default: "buyer_room", null: false
    t.datetime "accepted_at", null: false
    t.string "buyer_company"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.jsonb "difference_review", default: {}, null: false
    t.string "email", null: false
    t.string "evidence_summary"
    t.boolean "has_differences", default: false, null: false
    t.string "idempotency_key", null: false
    t.string "job_title"
    t.string "name", null: false
    t.text "note"
    t.string "po_number"
    t.bigint "quote_id", null: false
    t.bigint "quote_revision_id", null: false
    t.bigint "recorded_by_id"
    t.jsonb "selection", default: {}, null: false
    t.boolean "seller_recorded", default: false, null: false
    t.jsonb "snapshot", default: {}, null: false
    t.decimal "total", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_quote_acceptances_on_company_id"
    t.index ["quote_id", "idempotency_key"], name: "idx_quote_acceptances_idempotency", unique: true
    t.index ["quote_id"], name: "index_quote_acceptances_on_quote_id"
    t.index ["quote_revision_id"], name: "index_quote_acceptances_on_quote_revision_id", unique: true
    t.index ["recorded_by_id"], name: "index_quote_acceptances_on_recorded_by_id"
  end

  create_table "quote_items", force: :cascade do |t|
    t.jsonb "addon_charges", default: [], null: false
    t.jsonb "addon_snapshot", default: [], null: false
    t.decimal "amount", precision: 15, scale: 4
    t.jsonb "buyer_options", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "image_source", default: "none", null: false
    t.string "item_type", default: "product_main", null: false
    t.string "lead_time_snapshot"
    t.string "packing_snapshot"
    t.string "price_source", default: "manual", null: false
    t.integer "product_id"
    t.integer "quantity", default: 1, null: false
    t.bigint "quote_id", null: false
    t.string "selection_mode", default: "fixed", null: false
    t.string "sku_snapshot"
    t.jsonb "spec_snapshot", default: [], null: false
    t.jsonb "specifications", default: [], null: false
    t.decimal "unit_price", precision: 15, scale: 4, null: false
    t.string "unit_snapshot"
    t.datetime "updated_at", null: false
    t.index ["quote_id", "created_at"], name: "index_quote_items_on_quote_id_and_created_at"
    t.index ["quote_id", "item_type", "created_at"], name: "index_quote_items_on_quote_id_and_item_type_and_created_at"
    t.index ["quote_id"], name: "index_quote_items_on_quote_id"
  end

  create_table "quote_preset_masters", force: :cascade do |t|
    t.bigint "advanced_logistics_preset_id"
    t.bigint "advanced_trade_terms_preset_id"
    t.bigint "business_terms_preset_id"
    t.bigint "company_id", null: false
    t.bigint "configuration_block_preset_id"
    t.bigint "container_loading_preset_id"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "formal_closing_preset_id"
    t.datetime "updated_at", null: false
    t.index ["advanced_logistics_preset_id"], name: "index_quote_preset_masters_on_advanced_logistics_preset_id"
    t.index ["advanced_trade_terms_preset_id"], name: "index_quote_preset_masters_on_advanced_trade_terms_preset_id"
    t.index ["business_terms_preset_id"], name: "index_quote_preset_masters_on_business_terms_preset_id"
    t.index ["company_id"], name: "index_quote_preset_masters_on_company_id", unique: true
    t.index ["configuration_block_preset_id"], name: "index_quote_preset_masters_on_configuration_block_preset_id"
    t.index ["container_loading_preset_id"], name: "index_quote_preset_masters_on_container_loading_preset_id"
    t.index ["formal_closing_preset_id"], name: "index_quote_preset_masters_on_formal_closing_preset_id"
  end

  create_table "quote_presets", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "module_key", null: false
    t.string "name", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "module_key", "active"], name: "idx_quote_presets_company_module_active"
    t.index ["company_id", "module_key", "name"], name: "idx_quote_presets_company_module_name", unique: true
    t.index ["company_id"], name: "index_quote_presets_on_company_id"
  end

  create_table "quote_reason_options", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "kind", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "kind", "active", "position"], name: "idx_quote_reason_options_company_kind_order"
    t.index ["company_id", "kind", "key"], name: "idx_quote_reason_options_company_kind_key", unique: true
    t.index ["company_id"], name: "index_quote_reason_options_on_company_id"
  end

  create_table "quote_revisions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", null: false
    t.jsonb "diff", default: {}, null: false
    t.datetime "expires_at"
    t.integer "number", null: false
    t.datetime "published_at"
    t.bigint "quote_id", null: false
    t.datetime "revoked_at"
    t.string "secure_token", null: false
    t.datetime "sent_at"
    t.jsonb "snapshot", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.text "summary"
    t.datetime "superseded_at"
    t.decimal "total", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_quote_revisions_on_company_id"
    t.index ["created_by_id"], name: "index_quote_revisions_on_created_by_id"
    t.index ["quote_id", "number"], name: "index_quote_revisions_on_quote_id_and_number", unique: true
    t.index ["quote_id", "status"], name: "index_quote_revisions_on_quote_id_and_status"
    t.index ["quote_id"], name: "index_quote_revisions_on_quote_id"
    t.index ["secure_token"], name: "index_quote_revisions_on_secure_token", unique: true
  end

  create_table "quote_shares", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "first_viewed_at"
    t.datetime "last_viewed_at"
    t.bigint "quote_id", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0, null: false
    t.jsonb "view_events", default: [], null: false
    t.index ["company_id"], name: "index_quote_shares_on_company_id"
    t.index ["quote_id"], name: "index_quote_shares_on_quote_id"
    t.index ["token"], name: "index_quote_shares_on_token", unique: true
  end

  create_table "quote_templates", force: :cascade do |t|
    t.string "accent_color", default: "#1F4E79", null: false
    t.string "addon_label", default: "Add-on", null: false
    t.jsonb "advanced_defaults", default: {}, null: false
    t.jsonb "advanced_visibility_defaults", default: {}, null: false
    t.integer "amount_decimals", default: 2, null: false
    t.text "closing_message", default: "If you have questions, reply directly to this quote. Ready to proceed? Let us know.", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency_display_mode", default: "symbol_prefix", null: false
    t.text "default_scope_of_supply_content"
    t.boolean "default_template", default: false, null: false
    t.string "description_label", default: "Description", null: false
    t.string "document_kind", default: "quotation", null: false
    t.string "document_number_label", default: "", null: false
    t.string "document_title", default: "", null: false
    t.boolean "enable_advanced_by_default", default: false, null: false
    t.string "excel_locale", default: "en", null: false
    t.boolean "excel_show_grid_lines", default: false, null: false
    t.string "font_family", default: "Noto Sans", null: false
    t.text "footer_note", default: "", null: false
    t.text "footer_text", default: "", null: false
    t.string "layout_density", default: "standard", null: false
    t.string "layout_type", default: "classic", null: false
    t.string "line_total_label", default: "Line Total", null: false
    t.string "logo_position", default: "right", null: false
    t.string "name", default: "Default Template", null: false
    t.string "pdf_locale", default: "en", null: false
    t.text "pi_footer_note", default: "", null: false
    t.string "pi_number_label", default: "", null: false
    t.string "pi_title", default: "", null: false
    t.string "public_link_locale", default: "en", null: false
    t.string "qty_label", default: "Qty", null: false
    t.text "quotation_footer_note", default: "", null: false
    t.string "quotation_number_label", default: "", null: false
    t.string "quotation_title", default: "", null: false
    t.string "scope_of_supply_label"
    t.boolean "show_closing_message", default: true, null: false
    t.boolean "show_currency", default: true, null: false
    t.boolean "show_customer_owner", default: true, null: false
    t.boolean "show_excel_revision_summary", default: true, null: false
    t.boolean "show_images", default: true, null: false
    t.boolean "show_logo", default: true, null: false
    t.boolean "show_negotiated_flag", default: false, null: false
    t.boolean "show_notes", default: true, null: false
    t.boolean "show_payment_term", default: true, null: false
    t.boolean "show_pdf_revision_summary", default: true, null: false
    t.boolean "show_product_images", default: true, null: false
    t.boolean "show_public_revision_summary", default: true, null: false
    t.boolean "show_saas_branding", default: false, null: false
    t.boolean "show_scope_of_supply", default: false, null: false
    t.boolean "show_shipping", default: true, null: false
    t.boolean "show_signature_block", default: false, null: false
    t.boolean "show_tax", default: true, null: false
    t.boolean "show_terms_section", default: true, null: false
    t.boolean "show_valid_until", default: true, null: false
    t.boolean "show_watermark", default: false, null: false
    t.string "signature_name"
    t.string "slug", default: "default-template", null: false
    t.string "spec_label", default: "Spec", null: false
    t.string "thousand_separator", default: "comma", null: false
    t.string "unit_price_label", default: "Unit Price", null: false
    t.datetime "updated_at", null: false
    t.integer "watermark_opacity", default: 12, null: false
    t.string "watermark_text", default: "", null: false
    t.string "webview_locale", default: "en", null: false
    t.index ["company_id", "slug"], name: "index_quote_templates_on_company_id_and_slug", unique: true
    t.index ["company_id"], name: "index_quote_templates_on_company_id"
  end

  create_table "quote_view_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms", comment: "Time spent on page in milliseconds"
    t.bigint "quote_share_id", null: false
    t.datetime "updated_at", null: false
    t.index ["quote_share_id", "created_at"], name: "index_quote_view_events_on_quote_share_id_and_created_at"
    t.index ["quote_share_id"], name: "index_quote_view_events_on_quote_share_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "addon_label"
    t.jsonb "advanced_logistics", default: {}, null: false
    t.boolean "advanced_mode", default: false, null: false
    t.jsonb "advanced_trade_terms", default: {}, null: false
    t.jsonb "advanced_visibility", default: {}, null: false
    t.datetime "archived_at"
    t.string "buyer_locale", default: "en", null: false
    t.text "changes_request_message"
    t.datetime "changes_requested_at"
    t.bigint "company_id", null: false
    t.jsonb "configuration_block", default: {}, null: false
    t.jsonb "container_loading_block", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "custom_title"
    t.bigint "customer_id", null: false
    t.datetime "deleted_at"
    t.text "delivery_notes"
    t.jsonb "detail_pictures_block", default: {}, null: false
    t.decimal "discount_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "final_amount", precision: 15, scale: 4
    t.date "follow_up_on"
    t.jsonb "formal_closing_block", default: {}, null: false
    t.bigint "inquiry_id"
    t.text "internal_note"
    t.date "issued_on"
    t.string "language", default: "zh-CN", null: false
    t.text "legal_disclaimer"
    t.string "loss_reason"
    t.string "loss_reason_detail"
    t.datetime "lost_at"
    t.boolean "negotiated"
    t.string "next_action"
    t.text "notes"
    t.string "payment_term"
    t.string "product_name"
    t.integer "quantity"
    t.string "quote_no"
    t.integer "reminder_count", default: 0, null: false
    t.datetime "reminder_sent_at"
    t.datetime "reopened_at"
    t.string "request_reason"
    t.integer "revision_number"
    t.text "scope_of_supply"
    t.datetime "sent_at"
    t.decimal "shipping_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "shipping_price_source"
    t.bigint "source_quote_id"
    t.string "spec_label"
    t.string "stalled_reason"
    t.string "stalled_reason_detail"
    t.string "status"
    t.string "studio_state", default: "draft", null: false
    t.decimal "tax_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.bigint "template_id"
    t.text "terms_text"
    t.string "trade_term"
    t.decimal "unit_price", precision: 15, scale: 4
    t.datetime "updated_at", null: false
    t.date "valid_until"
    t.datetime "viewed_at"
    t.string "win_reason"
    t.string "win_reason_detail"
    t.datetime "won_at"
    t.index ["accepted_at"], name: "index_quotes_on_accepted_at"
    t.index ["changes_requested_at"], name: "index_quotes_on_changes_requested_at"
    t.index ["company_id", "quote_no", "archived_at"], name: "index_quotes_on_company_quote_archived_at"
    t.index ["company_id"], name: "index_quotes_on_company_id"
    t.index ["customer_id"], name: "index_quotes_on_customer_id"
    t.index ["deleted_at"], name: "index_quotes_on_deleted_at"
    t.index ["inquiry_id"], name: "index_quotes_on_inquiry_id"
    t.index ["reminder_sent_at"], name: "index_quotes_on_reminder_sent_at"
    t.index ["request_reason"], name: "index_quotes_on_request_reason"
    t.index ["source_quote_id"], name: "index_quotes_on_source_quote_id_unique", unique: true, where: "(source_quote_id IS NOT NULL)"
    t.index ["template_id"], name: "index_quotes_on_template_id"
  end

  create_table "spec_presets", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "entries", default: [], null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_spec_presets_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_spec_presets_on_company_id"
  end

  create_table "subscription_events", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "provider_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_subscription_events_on_company_id"
    t.index ["provider_event_id"], name: "index_subscription_events_on_provider_event_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id"
    t.integer "company_role", default: 2, null: false
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.boolean "dismissed_onboarding", default: false, null: false
    t.string "email", default: "", null: false
    t.datetime "email_change_sent_at"
    t.string "email_change_token"
    t.integer "email_verification_attempts", default: 0, null: false
    t.string "email_verification_code_digest"
    t.datetime "email_verification_code_sent_at"
    t.datetime "email_verified_at"
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.string "job_title"
    t.string "language", default: "zh-CN"
    t.datetime "last_active_at"
    t.datetime "last_login_at"
    t.string "pending_email"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.datetime "vip_expires_at"
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["company_role"], name: "index_users_on_company_role"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_change_token"], name: "index_users_on_email_change_token", unique: true
    t.index ["last_active_at"], name: "index_users_on_last_active_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["vip_expires_at"], name: "index_users_on_vip_expires_at"
  end

  create_table "version_deliveries", force: :cascade do |t|
    t.string "cc"
    t.string "channel", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "delivered_at"
    t.text "error_message"
    t.string "execution_type", default: "system", null: false
    t.string "external_channel"
    t.string "file_name"
    t.bigint "file_size"
    t.datetime "generated_at"
    t.string "idempotency_key", null: false
    t.text "message_body"
    t.text "note"
    t.bigint "quote_id", null: false
    t.bigint "quote_revision_id", null: false
    t.string "recipient"
    t.bigint "retry_of_id"
    t.string "status", default: "queued", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_version_deliveries_on_company_id"
    t.index ["created_by_id"], name: "index_version_deliveries_on_created_by_id"
    t.index ["quote_id"], name: "index_version_deliveries_on_quote_id"
    t.index ["quote_revision_id", "idempotency_key"], name: "idx_version_deliveries_idempotency", unique: true
    t.index ["quote_revision_id"], name: "index_version_deliveries_on_quote_revision_id"
    t.index ["retry_of_id"], name: "index_version_deliveries_on_retry_of_id"
  end

  add_foreign_key "action_items", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addon_presets", "companies"
  add_foreign_key "ai_analyses", "companies"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "buyer_activities", "companies"
  add_foreign_key "buyer_activities", "quote_revisions"
  add_foreign_key "buyer_activities", "quotes"
  add_foreign_key "buyer_questions", "companies"
  add_foreign_key "buyer_questions", "quote_revisions"
  add_foreign_key "change_requests", "companies"
  add_foreign_key "change_requests", "quote_revisions"
  add_foreign_key "company_documents", "companies"
  add_foreign_key "company_profile_imports", "companies"
  add_foreign_key "company_profile_imports", "users", column: "created_by_id"
  add_foreign_key "customer_follow_up_events", "customers"
  add_foreign_key "customer_follow_up_events", "quotes"
  add_foreign_key "customer_follow_up_events", "users"
  add_foreign_key "customer_taggings", "customer_tags"
  add_foreign_key "customer_taggings", "customers"
  add_foreign_key "customer_tags", "companies"
  add_foreign_key "customers", "companies"
  add_foreign_key "customers", "users", column: "internal_owner_id"
  add_foreign_key "deal_responses", "companies"
  add_foreign_key "deal_responses", "quote_revisions"
  add_foreign_key "deal_responses", "quotes"
  add_foreign_key "deal_responses", "users", column: "recorded_by_id"
  add_foreign_key "evidence_records", "ai_analyses"
  add_foreign_key "evidence_records", "companies"
  add_foreign_key "final_documents", "companies"
  add_foreign_key "final_documents", "quote_acceptances"
  add_foreign_key "final_documents", "quotes"
  add_foreign_key "final_documents", "users", column: "created_by_id"
  add_foreign_key "inquiries", "companies"
  add_foreign_key "inquiries", "customers"
  add_foreign_key "inquiries", "users", column: "created_by_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "product_addon_presets", "addon_presets"
  add_foreign_key "product_addon_presets", "products"
  add_foreign_key "product_import_batches", "companies"
  add_foreign_key "product_import_batches", "users", column: "created_by_id"
  add_foreign_key "product_import_candidates", "product_import_batches"
  add_foreign_key "product_import_candidates", "products", column: "matched_product_id"
  add_foreign_key "product_spec_presets", "products"
  add_foreign_key "product_spec_presets", "spec_presets"
  add_foreign_key "products", "addon_presets", column: "default_addon_preset_id"
  add_foreign_key "products", "companies"
  add_foreign_key "products", "spec_presets", column: "default_spec_preset_id"
  add_foreign_key "proforma_invoices", "companies"
  add_foreign_key "proforma_invoices", "quote_acceptances"
  add_foreign_key "proforma_invoices", "quotes"
  add_foreign_key "proforma_invoices", "users", column: "created_by_id"
  add_foreign_key "quote_acceptances", "companies"
  add_foreign_key "quote_acceptances", "quote_revisions"
  add_foreign_key "quote_acceptances", "quotes"
  add_foreign_key "quote_acceptances", "users", column: "recorded_by_id"
  add_foreign_key "quote_items", "quotes"
  add_foreign_key "quote_preset_masters", "companies"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "advanced_logistics_preset_id"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "advanced_trade_terms_preset_id"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "business_terms_preset_id"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "configuration_block_preset_id"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "container_loading_preset_id"
  add_foreign_key "quote_preset_masters", "quote_presets", column: "formal_closing_preset_id"
  add_foreign_key "quote_presets", "companies"
  add_foreign_key "quote_reason_options", "companies"
  add_foreign_key "quote_revisions", "companies"
  add_foreign_key "quote_revisions", "quotes"
  add_foreign_key "quote_revisions", "users", column: "created_by_id"
  add_foreign_key "quote_shares", "companies"
  add_foreign_key "quote_shares", "quotes"
  add_foreign_key "quote_templates", "companies"
  add_foreign_key "quote_view_events", "quote_shares"
  add_foreign_key "quotes", "companies"
  add_foreign_key "quotes", "customers"
  add_foreign_key "quotes", "inquiries"
  add_foreign_key "quotes", "quote_templates", column: "template_id"
  add_foreign_key "quotes", "quotes", column: "source_quote_id"
  add_foreign_key "spec_presets", "companies"
  add_foreign_key "subscription_events", "companies"
  add_foreign_key "users", "companies"
  add_foreign_key "version_deliveries", "companies"
  add_foreign_key "version_deliveries", "quote_revisions"
  add_foreign_key "version_deliveries", "quotes"
  add_foreign_key "version_deliveries", "users", column: "created_by_id"
  add_foreign_key "version_deliveries", "version_deliveries", column: "retry_of_id"
end
