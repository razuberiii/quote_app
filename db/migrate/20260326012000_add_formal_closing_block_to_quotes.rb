class AddFormalClosingBlockToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :formal_closing_block, :jsonb, null: false, default: {}
  end
end
