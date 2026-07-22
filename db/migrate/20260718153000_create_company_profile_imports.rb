class CreateCompanyProfileImports < ActiveRecord::Migration[8.1]
  def change
    create_table :company_profile_imports do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "draft"
      t.text :source_text
      t.jsonb :candidate_data, null: false, default: {}
      t.jsonb :warnings, null: false, default: []
      t.timestamps
    end
    add_index :company_profile_imports, [ :company_id, :status ]
  end
end
