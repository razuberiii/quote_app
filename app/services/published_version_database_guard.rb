class PublishedVersionDatabaseGuard
  def self.install!
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION protect_published_quote_revision_content()
      RETURNS trigger AS $$
      BEGIN
        IF OLD.published_at IS NOT NULL AND (
          NEW.snapshot IS DISTINCT FROM OLD.snapshot OR NEW.currency IS DISTINCT FROM OLD.currency OR
          NEW.total IS DISTINCT FROM OLD.total OR NEW.number IS DISTINCT FROM OLD.number OR
          NEW.published_at IS DISTINCT FROM OLD.published_at OR NEW.quote_id IS DISTINCT FROM OLD.quote_id OR
          NEW.company_id IS DISTINCT FROM OLD.company_id
        ) THEN RAISE EXCEPTION 'Published Version content is immutable'; END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      DROP TRIGGER IF EXISTS quote_revisions_immutable_content ON quote_revisions;
      CREATE TRIGGER quote_revisions_immutable_content BEFORE UPDATE ON quote_revisions
      FOR EACH ROW EXECUTE FUNCTION protect_published_quote_revision_content();
    SQL
  end
end
