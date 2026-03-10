class AddOutputLocalesToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_templates, :webview_locale, :string, null: false, default: "en"
    add_column :quote_templates, :public_link_locale, :string, null: false, default: "en"
    add_column :quote_templates, :pdf_locale, :string, null: false, default: "en"
    add_column :quote_templates, :excel_locale, :string, null: false, default: "en"
  end
end
