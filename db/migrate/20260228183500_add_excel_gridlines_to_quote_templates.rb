class AddExcelGridlinesToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_templates, :excel_show_grid_lines, :boolean, null: false, default: false
  end
end
