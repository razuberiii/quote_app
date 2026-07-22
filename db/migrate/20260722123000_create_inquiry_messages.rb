class CreateInquiryMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :inquiry_messages do |t|
      t.references :inquiry, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.string :direction, null: false, default: "buyer"
      t.string :channel, null: false, default: "email"
      t.text :body
      t.datetime :occurred_at, null: false
      t.jsonb :change_summary, null: false, default: {}
      t.timestamps
    end

    add_index :inquiry_messages, %i[inquiry_id occurred_at]
  end
end
