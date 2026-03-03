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

ActiveRecord::Schema[8.1].define(version: 2026_03_03_030000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.datetime "updated_at", null: false
    t.string "website"
  end

  create_table "customer_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "customer_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "customer_tag_id"], name: "index_customer_taggings_on_customer_id_and_customer_tag_id", unique: true
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
    t.decimal "estimated_annual_volume", precision: 15, scale: 2
    t.bigint "internal_owner_id"
    t.date "last_follow_up_date"
    t.string "main_product_interest"
    t.string "name"
    t.date "next_follow_up_date"
    t.text "notes"
    t.string "payment_terms"
    t.string "phone"
    t.string "status"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_customers_on_company_id"
    t.index ["internal_owner_id"], name: "index_customers_on_internal_owner_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.decimal "cost_price", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.decimal "default_price", precision: 15, scale: 4, null: false
    t.text "default_specification"
    t.text "description"
    t.string "lead_time"
    t.integer "moq"
    t.string "name", null: false
    t.string "price_currency", default: "USD", null: false
    t.string "product_category"
    t.string "sku", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["company_id", "sku"], name: "index_products_on_company_id_and_sku", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
  end

  create_table "quote_items", force: :cascade do |t|
    t.jsonb "addon_charges", default: [], null: false
    t.decimal "amount", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "product_id"
    t.integer "quantity", default: 1, null: false
    t.bigint "quote_id", null: false
    t.jsonb "specifications", default: [], null: false
    t.decimal "unit_price", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id", "created_at"], name: "index_quote_items_on_quote_id_and_created_at"
    t.index ["quote_id"], name: "index_quote_items_on_quote_id"
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
    t.boolean "excel_show_grid_lines", default: false, null: false
    t.string "font_family", default: "Noto Sans", null: false
    t.text "footer_note", default: "", null: false
    t.text "footer_text", default: "", null: false
    t.string "layout_density", default: "standard", null: false
    t.string "layout_type", default: "classic", null: false
    t.string "line_total_label", default: "Line Total", null: false
    t.string "logo_position", default: "right", null: false
    t.string "name", default: "Default Template", null: false
    t.text "pi_footer_note", default: "", null: false
    t.string "pi_number_label", default: "", null: false
    t.string "pi_title", default: "", null: false
    t.string "qty_label", default: "Qty", null: false
    t.text "quotation_footer_note", default: "", null: false
    t.string "quotation_number_label", default: "", null: false
    t.string "quotation_title", default: "", null: false
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
    t.boolean "show_shipping", default: true, null: false
    t.boolean "show_signature_block", default: false, null: false
    t.boolean "show_tax", default: true, null: false
    t.boolean "show_terms_section", default: true, null: false
    t.boolean "show_valid_until", default: true, null: false
    t.string "slug", default: "default-template", null: false
    t.string "spec_label", default: "Spec", null: false
    t.string "thousand_separator", default: "comma", null: false
    t.string "unit_price_label", default: "Unit Price", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "slug"], name: "index_quote_templates_on_company_id_and_slug", unique: true
    t.index ["company_id"], name: "index_quote_templates_on_company_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "addon_label"
    t.text "changes_request_message"
    t.datetime "changes_requested_at"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "custom_title"
    t.bigint "customer_id", null: false
    t.text "delivery_notes"
    t.decimal "discount_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.decimal "final_amount", precision: 15, scale: 4
    t.date "issued_on"
    t.text "legal_disclaimer"
    t.string "loss_reason"
    t.boolean "negotiated"
    t.text "notes"
    t.string "payment_term"
    t.string "product_name"
    t.integer "quantity"
    t.string "quote_no"
    t.datetime "reopened_at"
    t.integer "revision_number"
    t.datetime "sent_at"
    t.decimal "shipping_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "spec_label"
    t.string "status"
    t.decimal "tax_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.bigint "template_id"
    t.text "terms_text"
    t.string "trade_term"
    t.decimal "unit_price", precision: 15, scale: 4
    t.datetime "updated_at", null: false
    t.date "valid_until"
    t.datetime "viewed_at"
    t.index ["accepted_at"], name: "index_quotes_on_accepted_at"
    t.index ["changes_requested_at"], name: "index_quotes_on_changes_requested_at"
    t.index ["company_id"], name: "index_quotes_on_company_id"
    t.index ["customer_id"], name: "index_quotes_on_customer_id"
    t.index ["template_id"], name: "index_quotes_on_template_id"
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
    t.string "email", default: "", null: false
    t.datetime "email_change_sent_at"
    t.string "email_change_token"
    t.string "email_verification_token"
    t.datetime "email_verification_token_sent_at"
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
    t.index ["email_verification_token"], name: "index_users_on_email_verification_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "customer_taggings", "customer_tags"
  add_foreign_key "customer_taggings", "customers"
  add_foreign_key "customer_tags", "companies"
  add_foreign_key "customers", "companies"
  add_foreign_key "customers", "users", column: "internal_owner_id"
  add_foreign_key "products", "companies"
  add_foreign_key "quote_items", "quotes"
  add_foreign_key "quote_shares", "companies"
  add_foreign_key "quote_shares", "quotes"
  add_foreign_key "quote_templates", "companies"
  add_foreign_key "quotes", "companies"
  add_foreign_key "quotes", "customers"
  add_foreign_key "quotes", "quote_templates", column: "template_id"
  add_foreign_key "team_invitations", "companies"
  add_foreign_key "team_invitations", "users", column: "invited_by_id"
  add_foreign_key "users", "companies"
end
