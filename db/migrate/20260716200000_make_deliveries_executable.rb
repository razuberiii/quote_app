class MakeDeliveriesExecutable < ActiveRecord::Migration[8.1]
  def up
    change_column_default :version_deliveries, :status, from: "succeeded", to: "queued"
    change_column_null :version_deliveries, :delivered_at, true
    change_column_null :version_deliveries, :idempotency_key, false
    add_column :version_deliveries, :execution_type, :string, null: false, default: "system"
    add_column :version_deliveries, :subject, :string
    add_column :version_deliveries, :message_body, :text
    add_column :version_deliveries, :cc, :string
    add_column :version_deliveries, :error_message, :text
    add_column :version_deliveries, :file_name, :string
    add_column :version_deliveries, :file_size, :bigint
    add_column :version_deliveries, :generated_at, :datetime
    add_reference :version_deliveries, :retry_of, foreign_key: { to_table: :version_deliveries }

    add_column :final_documents, :generated_at, :datetime
    add_column :final_documents, :file_name, :string
    add_column :final_documents, :file_size, :bigint
    add_column :final_documents, :error_message, :text

    execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_published_quote_revision_content()
      RETURNS trigger AS $$
      BEGIN
        IF OLD.published_at IS NOT NULL AND (
          NEW.snapshot IS DISTINCT FROM OLD.snapshot OR
          NEW.currency IS DISTINCT FROM OLD.currency OR
          NEW.total IS DISTINCT FROM OLD.total OR
          NEW.number IS DISTINCT FROM OLD.number OR
          NEW.published_at IS DISTINCT FROM OLD.published_at OR
          NEW.quote_id IS DISTINCT FROM OLD.quote_id OR
          NEW.company_id IS DISTINCT FROM OLD.company_id
        ) THEN
          RAISE EXCEPTION 'Published Version content is immutable';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER quote_revisions_immutable_content
      BEFORE UPDATE ON quote_revisions
      FOR EACH ROW EXECUTE FUNCTION protect_published_quote_revision_content();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS quote_revisions_immutable_content ON quote_revisions"
    execute "DROP FUNCTION IF EXISTS protect_published_quote_revision_content()"
    remove_column :final_documents, :error_message
    remove_column :final_documents, :file_size
    remove_column :final_documents, :file_name
    remove_column :final_documents, :generated_at
    remove_reference :version_deliveries, :retry_of
    remove_column :version_deliveries, :generated_at
    remove_column :version_deliveries, :file_size
    remove_column :version_deliveries, :file_name
    remove_column :version_deliveries, :error_message
    remove_column :version_deliveries, :cc
    remove_column :version_deliveries, :message_body
    remove_column :version_deliveries, :subject
    remove_column :version_deliveries, :execution_type
    change_column_null :version_deliveries, :idempotency_key, true
    change_column_null :version_deliveries, :delivered_at, false
    change_column_default :version_deliveries, :status, from: "queued", to: "succeeded"
  end
end
