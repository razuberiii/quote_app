class ConnectInquiriesToQuoteWorkflow < ActiveRecord::Migration[8.1]
  def change
    add_reference :quotes, :inquiry, foreign_key: true
    change_table :quote_items, bulk: true do |t|
      t.string :price_source, null: false, default: "manual"
      t.string :selection_mode, null: false, default: "fixed"
      t.jsonb :buyer_options, null: false, default: {}
      t.string :sku_snapshot
      t.string :unit_snapshot
      t.string :lead_time_snapshot
      t.string :packing_snapshot
    end
  end
end
