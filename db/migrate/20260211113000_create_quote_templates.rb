class CreateQuoteTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_templates do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }
      t.boolean :show_payment_term, null: false, default: true
      t.boolean :show_valid_until, null: false, default: true
      t.boolean :show_notes, null: false, default: true
      t.boolean :show_logo, null: false, default: true
      t.boolean :show_negotiated_flag, null: false, default: false

      t.timestamps
    end
  end
end
