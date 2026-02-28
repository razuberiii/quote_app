class AddPdfPresentationOptionsToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    change_table :quote_templates, bulk: true do |t|
      t.string :layout_density, null: false, default: "standard"
      t.integer :amount_decimals, null: false, default: 2
      t.string :thousand_separator, null: false, default: "comma"
      t.string :currency_display_mode, null: false, default: "symbol_prefix"
      t.string :description_label, null: false, default: "Description"
      t.string :qty_label, null: false, default: "Qty"
      t.string :unit_price_label, null: false, default: "Unit Price"
      t.string :line_total_label, null: false, default: "Line Total"
      t.string :logo_position, null: false, default: "right"
    end
  end
end
