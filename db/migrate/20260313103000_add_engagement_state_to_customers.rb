class AddEngagementStateToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :engagement_state, :string, null: false, default: "unassessed"
    add_column :customers, :manual_engagement_override, :boolean, null: false, default: false

    add_index :customers, :engagement_state
    add_index :customers, :manual_engagement_override
  end
end
