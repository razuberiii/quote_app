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
      validate_workspace!
      validate_readiness!
      raise PlanLimitReached, "Upgrade your plan to send another quote" unless @quote.company.can_send_quote?

      snapshot = QuoteSnapshotBuilder.new(@quote).as_json
      previous = @quote.quote_revisions.ordered.first
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
        sent_at: Time.current,
        expires_at: @quote.valid_until&.end_of_day
      )
      @quote.update!(status: previous ? "negotiating" : "sent", sent_at: Time.current, studio_state: "sent")
      url = if @url_options[:host].present?
        Rails.application.routes.url_helpers.buyer_room_url(revision.secure_token, @url_options)
      else
        Rails.application.routes.url_helpers.buyer_room_path(revision.secure_token)
      end
      Result.new(revision, url)
    end
  end

  private

  def validate_workspace!
    raise ActiveRecord::RecordNotFound unless @actor&.company_id == @quote.company_id
  end

  def validate_readiness!
    invalid_item = @quote.quote_items.any? { |item| item.description.blank? || item.quantity.to_i <= 0 || item.unit_price.nil? }
    raise NotReady, "Product, quantity, price, currency and validity must be confirmed" if invalid_item || @quote.currency.blank? || @quote.valid_until.blank?
  end
end
