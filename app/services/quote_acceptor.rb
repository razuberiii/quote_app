class QuoteAcceptor
  class NotActionable < StandardError; end

  def initialize(revision:, attributes:, selection:, idempotency_key:)
    @revision = revision
    @attributes = attributes
    @selection = selection || {}
    @idempotency_key = idempotency_key.presence || SecureRandom.uuid
  end

  def call
    @revision.quote.with_lock do
      existing = @revision.quote.quote_acceptance
      return existing if existing&.idempotency_key == @idempotency_key
      raise NotActionable, "Only the latest active revision can be accepted" unless @revision.actionable?
      raise NotActionable, "This quote has already been accepted" if existing

      acceptance = QuoteAcceptance.create!(
        company: @revision.company, quote: @revision.quote, quote_revision: @revision,
        name: @attributes.fetch(:name), email: @attributes.fetch(:email),
        job_title: @attributes[:job_title], po_number: @attributes[:po_number], note: @attributes[:note],
        selection: @selection, snapshot: @revision.snapshot.merge("buyer_selection" => @selection),
        total: @revision.total, currency: @revision.currency, idempotency_key: @idempotency_key,
        accepted_at: Time.current
      )
      @revision.update!(status: "accepted")
      @revision.quote.update!(status: "accepted", accepted_at: acceptance.accepted_at)
      acceptance
    end
  end
end
