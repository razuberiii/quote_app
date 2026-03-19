class EnableRevisionSummaryTogglesByDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :quote_templates, :show_public_revision_summary, from: false, to: true
    change_column_default :quote_templates, :show_pdf_revision_summary, from: false, to: true
    change_column_default :quote_templates, :show_excel_revision_summary, from: false, to: true

    execute <<~SQL.squish
      UPDATE quote_templates
      SET
        show_public_revision_summary = TRUE,
        show_pdf_revision_summary = TRUE,
        show_excel_revision_summary = TRUE
      WHERE
        show_public_revision_summary = FALSE
        OR show_pdf_revision_summary = FALSE
        OR show_excel_revision_summary = FALSE
    SQL
  end

  def down
    change_column_default :quote_templates, :show_public_revision_summary, from: true, to: false
    change_column_default :quote_templates, :show_pdf_revision_summary, from: true, to: false
    change_column_default :quote_templates, :show_excel_revision_summary, from: true, to: false
  end
end
