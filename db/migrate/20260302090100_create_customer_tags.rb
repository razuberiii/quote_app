class CreateCustomerTags < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_tags do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :customer_tags, [ :company_id, :name ], unique: true

    create_table :customer_taggings do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :customer_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :customer_taggings, [ :customer_id, :customer_tag_id ], unique: true
  end
end
