class AddWatermarkOpacityToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :watermark_opacity, :integer, default: 12, null: false
  end
end
