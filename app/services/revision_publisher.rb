class RevisionPublisher
  class NotReady < StandardError; end
  class PlanLimitReached < StandardError; end

  Result = Data.define(:revision, :url)

  def initialize(quote:, actor:, url_options: {})
    @quote = quote
    @actor = actor
    @url_options = url_options
  end

  def call
    @quote.with_lock do
      @quote.reload
      validate_workspace!
      validate_readiness!
      snapshot = QuoteSnapshotBuilder.new(@quote).as_json
      previous = @quote.quote_revisions.ordered.first
      if previous&.status == "current" && SnapshotDiff.new(previous.snapshot, snapshot).call.empty?
        return Result.new(previous, buyer_room_url(previous))
      end
      raise PlanLimitReached, "Upgrade your plan to publish another Version" unless @quote.company.can_send_quote?

      number = previous.present? ? previous.number + 1 : 1
      previous&.update!(status: "superseded", superseded_at: Time.current)

      revision = @quote.quote_revisions.create!(
        company: @quote.company,
        created_by: @actor,
        number: number,
        status: "current",
        currency: @quote.currency,
        total: @quote.grand_total,
        snapshot: snapshot,
        diff: previous ? SnapshotDiff.new(previous.snapshot, snapshot).call : {},
        summary: previous ? "Revision #{number} updates the previous quotation." : "Initial quotation.",
        secure_token: SecureRandom.urlsafe_base64(32),
        published_at: Time.current,
        expires_at: @quote.valid_until&.end_of_day
      )
      @quote.update!(status: "ready", studio_state: "published")
      Result.new(revision, buyer_room_url(revision))
    end
  end

  private

  def validate_workspace!
    raise ActiveRecord::RecordNotFound unless @actor&.company_id == @quote.company_id
  end

  def validate_readiness!
    issues = QuoteReadinessAudit.new(@quote).issues
    raise NotReady, issues.join(" · ") if issues.any?
  end

  def buyer_room_url(revision)
    if @url_options[:host].present?
      Rails.application.routes.url_helpers.buyer_room_url(revision.secure_token, @url_options)
    else
      Rails.application.routes.url_helpers.buyer_room_path(revision.secure_token)
    end
  end
end
