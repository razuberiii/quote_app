class CreateActionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :action_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action_type, null: false
      t.string :reference_type, null: false
      t.bigint :reference_id, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :action_items, [ :reference_type, :reference_id ]
    add_index :action_items, [ :user_id, :action_type, :reference_type, :reference_id ], name: "index_action_items_on_user_action_reference"
    add_index :action_items, [ :user_id, :resolved_at ]
  end
end
