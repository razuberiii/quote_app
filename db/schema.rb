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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_132000) do
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
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.string "website"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.bigint "company_id", null: false
    t.string "contact_name"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.date "last_follow_up_date"
    t.string "name"
    t.date "next_follow_up_date"
    t.text "notes"
    t.string "phone"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_customers_on_company_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "default_price", precision: 15, scale: 4, null: false
    t.text "description"
    t.string "name", null: false
    t.string "sku", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "sku"], name: "index_products_on_company_id_and_sku", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
  end

  create_table "quote_items", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 4
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "product_id"
    t.integer "quantity", default: 1, null: false
    t.bigint "quote_id", null: false
    t.decimal "unit_price", precision: 15, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["quote_id", "created_at"], name: "index_quote_items_on_quote_id_and_created_at"
    t.index ["quote_id"], name: "index_quote_items_on_quote_id"
  end

  create_table "quote_shares", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "quote_id", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_quote_shares_on_company_id"
    t.index ["quote_id"], name: "index_quote_shares_on_quote_id"
    t.index ["token"], name: "index_quote_shares_on_token", unique: true
  end

  create_table "quote_templates", force: :cascade do |t|
    t.string "accent_color", default: "#1F4E79", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "default_template", default: false, null: false
    t.string "document_kind", default: "quotation", null: false
    t.string "document_number_label", default: "", null: false
    t.string "document_title", default: "", null: false
    t.string "font_family", default: "Noto Sans", null: false
    t.text "footer_note", default: "", null: false
    t.text "footer_text", default: "", null: false
    t.string "layout_type", default: "classic", null: false
    t.string "name", default: "Default Template", null: false
    t.text "pi_footer_note", default: "", null: false
    t.string "pi_number_label", default: "", null: false
    t.string "pi_title", default: "", null: false
    t.text "quotation_footer_note", default: "", null: false
    t.string "quotation_number_label", default: "", null: false
    t.string "quotation_title", default: "", null: false
    t.boolean "show_currency", default: true, null: false
    t.boolean "show_images", default: true, null: false
    t.boolean "show_logo", default: true, null: false
    t.boolean "show_negotiated_flag", default: false, null: false
    t.boolean "show_notes", default: true, null: false
    t.boolean "show_payment_term", default: true, null: false
    t.boolean "show_product_images", default: true, null: false
    t.boolean "show_shipping", default: true, null: false
    t.boolean "show_signature_block", default: false, null: false
    t.boolean "show_tax", default: true, null: false
    t.boolean "show_terms_section", default: true, null: false
    t.boolean "show_valid_until", default: true, null: false
    t.string "slug", default: "default-template", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "slug"], name: "index_quote_templates_on_company_id_and_slug", unique: true
    t.index ["company_id"], name: "index_quote_templates_on_company_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency"
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
    t.integer "revision_number"
    t.decimal "shipping_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.string "status"
    t.decimal "tax_amount", precision: 15, scale: 4, default: "0.0", null: false
    t.bigint "template_id"
    t.text "terms_text"
    t.decimal "unit_price", precision: 15, scale: 4
    t.datetime "updated_at", null: false
    t.date "valid_until"
    t.index ["company_id"], name: "index_quotes_on_company_id"
    t.index ["customer_id"], name: "index_quotes_on_customer_id"
    t.index ["template_id"], name: "index_quotes_on_template_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "customers", "companies"
  add_foreign_key "products", "companies"
  add_foreign_key "quote_items", "quotes"
  add_foreign_key "quote_shares", "companies"
  add_foreign_key "quote_shares", "quotes"
  add_foreign_key "quote_templates", "companies"
  add_foreign_key "quotes", "companies"
  add_foreign_key "quotes", "customers"
  add_foreign_key "quotes", "quote_templates", column: "template_id"
  add_foreign_key "users", "companies"
end
