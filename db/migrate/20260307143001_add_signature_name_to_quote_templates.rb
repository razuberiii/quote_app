class AddSignatureNameToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :signature_name, :string
  end
end
