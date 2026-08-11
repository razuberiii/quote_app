class AddCustomFieldsToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_templates, :custom_fields, :jsonb, null: false, default: []
  end
end
