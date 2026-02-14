class AddPerDocumentCustomFieldsToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    change_table :quote_templates, bulk: true do |t|
      t.string :quotation_title, null: false, default: ""
      t.string :quotation_number_label, null: false, default: ""
      t.text :quotation_footer_note, null: false, default: ""
      t.string :pi_title, null: false, default: ""
      t.string :pi_number_label, null: false, default: ""
      t.text :pi_footer_note, null: false, default: ""
    end
  end
end
