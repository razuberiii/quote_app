class AddConfiguratorPresets < ActiveRecord::Migration[8.0]
  def change
    create_table :spec_presets do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :entries, null: false, default: []
      t.timestamps
    end

    create_table :addon_presets do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :entries, null: false, default: []
      t.timestamps
    end

    create_table :product_spec_presets do |t|
      t.references :product, null: false, foreign_key: true
      t.references :spec_preset, null: false, foreign_key: true
      t.timestamps
    end

    create_table :product_addon_presets do |t|
      t.references :product, null: false, foreign_key: true
      t.references :addon_preset, null: false, foreign_key: true
      t.timestamps
    end

    add_index :spec_presets, [ :company_id, :name ], unique: true
    add_index :addon_presets, [ :company_id, :name ], unique: true
    add_index :product_spec_presets, [ :product_id, :spec_preset_id ], unique: true
    add_index :product_addon_presets, [ :product_id, :addon_preset_id ], unique: true

    add_reference :products, :default_spec_preset, foreign_key: { to_table: :spec_presets }
    add_reference :products, :default_addon_preset, foreign_key: { to_table: :addon_presets }
  end
end
