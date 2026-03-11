class CreateCustomerFollowUpEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_follow_up_events do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :quote, foreign_key: true
      t.string :channel, null: false
      t.datetime :contacted_at, null: false
      t.text :note
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :customer_follow_up_events, [ :customer_id, :contacted_at ], name: "index_customer_follow_up_events_on_customer_and_contacted_at"
    add_index :customer_follow_up_events, :channel
  end
end
