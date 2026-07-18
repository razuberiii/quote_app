class AddStructuredAnalysisAndCatalogImports < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_analyses do |t|
      t.references :company, null: false, foreign_key: true
      t.references :source_record, polymorphic: true, null: false
      t.string :analysis_type, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :schema_version, null: false
      t.string :input_fingerprint, null: false
      t.integer :latency_ms
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :estimated_cost, precision: 12, scale: 6
      t.jsonb :raw_json, default: {}, null: false
      t.jsonb :validation_result, default: {}, null: false
      t.jsonb :accepted_fields, default: [], null: false
      t.jsonb :rejected_fields, default: [], null: false
      t.jsonb :corrected_fields, default: {}, null: false
      t.string :status, default: "validated", null: false
      t.timestamps
    end
    add_index :ai_analyses, %i[company_id analysis_type input_fingerprint], name: "idx_ai_analysis_fingerprint"

    create_table :evidence_records do |t|
      t.references :company, null: false, foreign_key: true
      t.references :source_record, polymorphic: true, null: false
      t.references :ai_analysis, foreign_key: true
      t.string :evidence_key, null: false
      t.string :field_path
      t.text :excerpt, null: false
      t.jsonb :locator, default: {}, null: false
      t.decimal :confidence, precision: 5, scale: 4
      t.timestamps
    end

    create_table :product_import_batches do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status, default: "review", null: false
      t.string :input_fingerprint, null: false
      t.jsonb :warnings, default: [], null: false
      t.timestamps
    end

    create_table :product_import_candidates do |t|
      t.references :product_import_batch, null: false, foreign_key: true
      t.references :matched_product, foreign_key: { to_table: :products }
      t.jsonb :candidate_data, default: {}, null: false
      t.jsonb :evidence, default: [], null: false
      t.decimal :confidence, precision: 5, scale: 4
      t.string :decision, default: "pending", null: false
      t.timestamps
    end
  end
end
