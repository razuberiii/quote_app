class TrackCatalogImportCoverage < ActiveRecord::Migration[8.0]
  def change
    add_column :product_import_batches, :processing_report, :jsonb, null: false, default: []
    change_column_null :products, :default_price, true
    change_column_default :products, :default_price, from: 0, to: nil
  end
end
