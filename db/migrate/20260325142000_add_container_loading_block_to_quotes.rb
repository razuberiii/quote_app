class AddContainerLoadingBlockToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :container_loading_block, :jsonb, null: false, default: {}
  end
end
