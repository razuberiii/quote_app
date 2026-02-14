class AddTemplateSystemToQuotesAndQuoteTemplates < ActiveRecord::Migration[8.1]
  def up
    add_reference :quotes, :template, foreign_key: { to_table: :quote_templates }, index: true

    remove_index :quote_templates, :company_id if index_exists?(:quote_templates, :company_id, unique: true)
    add_index :quote_templates, :company_id unless index_exists?(:quote_templates, :company_id)

    change_table :quote_templates, bulk: true do |t|
      t.string :name, null: false, default: "Default Template"
      t.string :slug, null: false, default: "default-template"
      t.string :layout_type, null: false, default: "classic"
      t.boolean :show_images, null: false, default: true
      t.boolean :show_tax, null: false, default: true
      t.boolean :show_shipping, null: false, default: true
      t.string :accent_color, null: false, default: "#1F4E79"
      t.string :font_family, null: false, default: "Noto Sans"
      t.text :footer_text, null: false, default: ""
      t.boolean :default_template, null: false, default: false
    end

    add_index :quote_templates, [ :company_id, :slug ], unique: true

    backfill_templates!
  end

  def down
    remove_index :quote_templates, [ :company_id, :slug ] if index_exists?(:quote_templates, [ :company_id, :slug ])

    remove_columns :quote_templates,
                   :name,
                   :slug,
                   :layout_type,
                   :show_images,
                   :show_tax,
                   :show_shipping,
                   :accent_color,
                   :font_family,
                   :footer_text,
                   :default_template

    remove_reference :quotes, :template, foreign_key: { to_table: :quote_templates }

    remove_index :quote_templates, :company_id if index_exists?(:quote_templates, :company_id)
    add_index :quote_templates, :company_id, unique: true
  end

  private

  def backfill_templates!
    execute <<~SQL.squish
      UPDATE quote_templates
      SET name = CASE
                   WHEN name IS NULL OR name = '' THEN 'Template ' || id
                   ELSE name
                 END,
          slug = CASE
                   WHEN slug IS NULL OR slug = '' THEN 'template-' || id
                   ELSE slug
                 END,
          layout_type = COALESCE(NULLIF(layout_type, ''), 'classic'),
          show_images = COALESCE(show_images, show_product_images, TRUE),
          show_tax = COALESCE(show_tax, TRUE),
          show_shipping = COALESCE(show_shipping, TRUE),
          accent_color = COALESCE(NULLIF(accent_color, ''), '#1F4E79'),
          font_family = COALESCE(NULLIF(font_family, ''), 'Noto Sans'),
          footer_text = COALESCE(footer_text, footer_note, ''),
          default_template = FALSE
    SQL

    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY id ASC) AS rn
        FROM quote_templates
      )
      UPDATE quote_templates qt
      SET default_template = TRUE
      FROM ranked
      WHERE qt.id = ranked.id
        AND ranked.rn = 1
    SQL

    execute <<~SQL.squish
      UPDATE quotes q
      SET template_id = qt.id
      FROM quote_templates qt
      WHERE qt.company_id = q.company_id
        AND qt.default_template = TRUE
        AND q.template_id IS NULL
    SQL
  end
end
