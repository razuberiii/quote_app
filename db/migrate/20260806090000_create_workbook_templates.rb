class CreateWorkbookTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :workbook_templates do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :field_mappings, null: false, default: {}
      t.jsonb :item_mapping, null: false, default: {}
      t.jsonb :custom_fields, null: false, default: []
      t.timestamps
    end

    add_reference :quotes, :workbook_template, foreign_key: true
    add_column :quotes, :custom_field_values, :jsonb, null: false, default: {}
  end
end
