class AddPresentationOptionsToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :closing_message, :text, null: false, default: "If you have questions, reply directly to this quote. Ready to proceed? Let us know."
    add_column :quote_templates, :show_closing_message, :boolean, null: false, default: true
    add_column :quote_templates, :show_saas_branding, :boolean, null: false, default: false
  end
end
