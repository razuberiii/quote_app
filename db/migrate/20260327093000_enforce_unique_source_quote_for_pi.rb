class EnforceUniqueSourceQuoteForPi < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:quotes, :source_quote_id)

    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY source_quote_id ORDER BY created_at DESC, id DESC) AS row_no
        FROM quotes
        WHERE source_quote_id IS NOT NULL
      )
      UPDATE quotes
      SET source_quote_id = NULL
      FROM ranked
      WHERE quotes.id = ranked.id
        AND ranked.row_no > 1
    SQL

    remove_index :quotes, name: "index_quotes_on_source_quote_id", if_exists: true
    add_index :quotes, :source_quote_id,
              unique: true,
              where: "source_quote_id IS NOT NULL",
              name: "index_quotes_on_source_quote_id_unique"
  end
end
