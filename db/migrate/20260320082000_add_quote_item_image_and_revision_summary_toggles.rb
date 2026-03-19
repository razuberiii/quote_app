class AddQuoteItemImageAndRevisionSummaryToggles < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_items, :image_source, :string, null: false, default: "none"

    add_column :quote_templates, :show_public_revision_summary, :boolean, null: false, default: false
    add_column :quote_templates, :show_pdf_revision_summary, :boolean, null: false, default: false
    add_column :quote_templates, :show_excel_revision_summary, :boolean, null: false, default: false
  end
end
