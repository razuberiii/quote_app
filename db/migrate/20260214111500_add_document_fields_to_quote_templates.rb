class AddDocumentFieldsToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    change_table :quote_templates, bulk: true do |t|
      t.string :document_kind, null: false, default: "quotation"
      t.string :document_title, null: false, default: ""
      t.string :document_number_label, null: false, default: ""
      t.text :footer_note, null: false, default: ""
    end
  end
end
