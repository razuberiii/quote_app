class AddDisplayOptionsToQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    change_table :quote_templates, bulk: true do |t|
      t.boolean :show_currency, null: false, default: true
      t.boolean :show_product_images, null: false, default: true
      t.boolean :show_terms_section, null: false, default: true
      t.boolean :show_signature_block, null: false, default: false
    end
  end
end
