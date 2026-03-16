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

ActiveRecord::Schema[8.1].define(version: 2026_03_16_120000) do
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

  create_table "companies", force: :cascade do |t|
    t.string "address"
    t.string "brand_color", default: "#1F4E79"
    t.datetime "created_at", null: false
    t.string "default_currency", default: "USD"
    t.string "default_payment_term"
    t.decimal "default_tax_rate", precision: 6, scale: 2, default: "0.0", null: false
    t.string "default_trade_term"
    t.integer "default_validity_days", default: 30, null: false
    t.string "email"
    t.string "legal_name"
    t.string "name"
    t.string "phone"
    t.text "registration_details"
    t.string "registration_number"
    t.text "reminder_email_body"
    t.string "reminder_email_cta_label"
    t.string "reminder_email_subject"
    t.datetime "updated_at", null: false
    t.string "website"
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
    t.decimal "default_price", precision: 15, scale: 4, null: false
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
    t.string "sku", null: false
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

  create_table "quote_items", force: :cascade do |t|
    t.jsonb "addon_charges", default: [], null: false
    t.jsonb "addon_snapshot", default: [], null: false
    t.decimal "amount", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "product_id"
    t.integer "quantity", default: 1, null: false
    t.bigint "quote_id", null: false
    t.jsonb "spec_snapshot", default: [], null: false
    t.jsonb "specifications", default: [], null: false
    t.decimal "unit_price", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id", "created_at"], name: "index_quote_items_on_quote_id_and_created_at"
    t.index ["quote_id"], name: "index_quote_items_on_quote_id"
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
    t.integer "amount_decimals", default: 2, null: false
    t.text "closing_message", default: "If you have questions, reply directly to this quote. Ready to proceed? Let us know.", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency_display_mode", default: "symbol_prefix", null: false
    t.boolean "default_template", default: false, null: false
    t.string "description_label", default: "Description", null: false
    t.string "document_kind", default: "quotation", null: false
    t.string "document_number_label", default: "", null: false
    t.string "document_title", default: "", null: false
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
    t.boolean "show_images", default: true, null: false
    t.boolean "show_logo", default: true, null: false
    t.boolean "show_negotiated_flag", default: false, null: false
    t.boolean "show_notes", default: true, null: false
    t.boolean "show_payment_term", default: true, null: false
    t.boolean "show_product_images", default: true, null: false
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
    t.datetime "archived_at"
    t.text "changes_request_message"
    t.datetime "changes_requested_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "custom_title"
    t.bigint "customer_id", null: false
    t.datetime "deleted_at"
    t.text "delivery_notes"
    t.decimal "discount_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "final_amount", precision: 15, scale: 4
    t.date "issued_on"
    t.text "legal_disclaimer"
    t.string "loss_reason"
    t.string "loss_reason_detail"
    t.datetime "lost_at"
    t.boolean "negotiated"
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
    t.string "spec_label"
    t.string "stalled_reason"
    t.string "stalled_reason_detail"
    t.string "status"
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
    t.index ["reminder_sent_at"], name: "index_quotes_on_reminder_sent_at"
    t.index ["request_reason"], name: "index_quotes_on_request_reason"
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

  create_table "team_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "company_id", null: false
    t.integer "company_role", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email", "accepted_at"], name: "index_team_invites_on_company_email_status"
    t.index ["company_id"], name: "index_team_invitations_on_company_id"
    t.index ["invited_by_id"], name: "index_team_invitations_on_invited_by_id"
    t.index ["token"], name: "index_team_invitations_on_token", unique: true
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
    t.string "language"
    t.string "pending_email"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["company_role"], name: "index_users_on_company_role"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_change_token"], name: "index_users_on_email_change_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "action_items", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addon_presets", "companies"
  add_foreign_key "company_documents", "companies"
  add_foreign_key "customer_follow_up_events", "customers"
  add_foreign_key "customer_follow_up_events", "quotes"
  add_foreign_key "customer_follow_up_events", "users"
  add_foreign_key "customer_taggings", "customer_tags"
  add_foreign_key "customer_taggings", "customers"
  add_foreign_key "customer_tags", "companies"
  add_foreign_key "customers", "companies"
  add_foreign_key "customers", "users", column: "internal_owner_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "product_addon_presets", "addon_presets"
  add_foreign_key "product_addon_presets", "products"
  add_foreign_key "product_spec_presets", "products"
  add_foreign_key "product_spec_presets", "spec_presets"
  add_foreign_key "products", "addon_presets", column: "default_addon_preset_id"
  add_foreign_key "products", "companies"
  add_foreign_key "products", "spec_presets", column: "default_spec_preset_id"
  add_foreign_key "quote_items", "quotes"
  add_foreign_key "quote_reason_options", "companies"
  add_foreign_key "quote_shares", "companies"
  add_foreign_key "quote_shares", "quotes"
  add_foreign_key "quote_templates", "companies"
  add_foreign_key "quote_view_events", "quote_shares"
  add_foreign_key "quotes", "companies"
  add_foreign_key "quotes", "customers"
  add_foreign_key "quotes", "quote_templates", column: "template_id"
  add_foreign_key "spec_presets", "companies"
  add_foreign_key "team_invitations", "companies"
  add_foreign_key "team_invitations", "users", column: "invited_by_id"
  add_foreign_key "users", "companies"
end
