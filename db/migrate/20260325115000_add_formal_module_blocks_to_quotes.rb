class AddFormalModuleBlocksToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :configuration_block, :jsonb, null: false, default: {}
    add_column :quotes, :detail_pictures_block, :jsonb, null: false, default: {}
  end
end
