class CreateQuoteViewEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_view_events do |t|
      t.references :quote_share, null: false, foreign_key: true
      t.integer :duration_ms, comment: "Time spent on page in milliseconds"

      t.timestamps
    end

    add_index :quote_view_events, [ :quote_share_id, :created_at ]
  end
end
