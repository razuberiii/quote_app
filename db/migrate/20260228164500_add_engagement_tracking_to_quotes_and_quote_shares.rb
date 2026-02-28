class AddEngagementTrackingToQuotesAndQuoteShares < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :sent_at, :datetime
    add_column :quotes, :viewed_at, :datetime

    add_column :quote_shares, :view_count, :integer, default: 0, null: false
    add_column :quote_shares, :last_viewed_at, :datetime
  end
end
