class AddSourceQuoteToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_reference :quotes, :source_quote, foreign_key: { to_table: :quotes }, index: true, null: true
  end
end
