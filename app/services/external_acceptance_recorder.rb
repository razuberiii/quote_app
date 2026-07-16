class ExternalAcceptanceRecorder
  class NotActionable < StandardError; end

  def initialize(revision:, actor:, attributes:, idempotency_key:)
    @revision = revision
    @actor = actor
    @attributes = attributes
    @idempotency_key = idempotency_key.presence || SecureRandom.uuid
  end

  def call
    @revision.quote.with_lock do
      raise ActiveRecord::RecordNotFound unless @actor.company_id == @revision.company_id
      existing = @revision.quote.quote_acceptance
      return existing if existing&.idempotency_key == @idempotency_key
      raise NotActionable, "Acceptance must reference the latest published Version" unless @revision.actionable?
      raise NotActionable, "This Deal already has an Acceptance" if existing

      acceptance = QuoteAcceptance.create!(
        company: @revision.company, quote: @revision.quote, quote_revision: @revision,
        recorded_by: @actor, seller_recorded: true,
        acceptance_method: @attributes.fetch(:acceptance_method), name: @attributes.fetch(:name),
        email: @attributes[:email].presence || "", buyer_company: @attributes[:buyer_company],
        po_number: @attributes[:po_number], note: @attributes[:note],
        has_differences: !!ActiveModel::Type::Boolean.new.cast(@attributes[:has_differences]),
        evidence_summary: @attributes[:evidence_summary], selection: {},
        snapshot: @revision.snapshot.deep_dup, total: @revision.total, currency: @revision.currency,
        idempotency_key: @idempotency_key, accepted_at: @attributes[:accepted_at].presence || Time.current
      )
      Array(@attributes[:evidence_files]).compact_blank.each { |file| acceptance.evidence_files.attach(file) }
      @revision.update!(status: "accepted")
      @revision.quote.update!(status: "accepted", accepted_at: acceptance.accepted_at)
      acceptance
    end
  end
end
