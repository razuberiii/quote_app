class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false, comment: "Type of notification: quote_viewed, etc"
      t.jsonb :data, default: {}, comment: "Contextual data: quote_id, quote_no, customer_name, etc"
      t.datetime :read_at, comment: "When user read the notification"
      t.datetime :dismissed_at, comment: "When user dismissed the notification"

      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ], order: { created_at: :desc }
    add_index :notifications, [ :user_id, :read_at ]
  end
end
