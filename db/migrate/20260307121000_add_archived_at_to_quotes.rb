class AddArchivedAtToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :archived_at, :datetime
    add_index :quotes, [ :company_id, :quote_no, :archived_at ], name: "index_quotes_on_company_quote_archived_at"
  end
end
