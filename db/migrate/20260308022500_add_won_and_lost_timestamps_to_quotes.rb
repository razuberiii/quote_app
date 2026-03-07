class AddWonAndLostTimestampsToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :won_at, :datetime
    add_column :quotes, :lost_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE quotes
          SET won_at = updated_at
          WHERE status = 'won' AND won_at IS NULL
        SQL

        execute <<~SQL
          UPDATE quotes
          SET lost_at = updated_at
          WHERE status = 'lost' AND lost_at IS NULL
        SQL
      end
    end
  end
end
