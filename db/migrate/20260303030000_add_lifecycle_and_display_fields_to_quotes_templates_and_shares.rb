class AddLifecycleAndDisplayFieldsToQuotesTemplatesAndShares < ActiveRecord::Migration[8.1]
  def change
    change_table :quote_templates, bulk: true do |t|
      t.string :spec_label, null: false, default: "Spec"
      t.string :addon_label, null: false, default: "Add-on"
    end

    change_table :quotes, bulk: true do |t|
      t.string :spec_label
      t.string :addon_label
      t.string :custom_title
      t.datetime :accepted_at
      t.datetime :changes_requested_at
      t.text :changes_request_message
      t.datetime :reopened_at
    end

    add_index :quotes, :accepted_at
    add_index :quotes, :changes_requested_at

    add_column :quote_shares, :view_events, :jsonb, null: false, default: []
  end
end
