class AddWatermarkToQuoteTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_templates, :show_watermark, :boolean, null: false, default: false
    add_column :quote_templates, :watermark_text, :string, null: false, default: ""
  end
end
