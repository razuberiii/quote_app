class AddWinAndStalledReasonsToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :win_reason, :string
    add_column :quotes, :stalled_reason, :string
  end
end
