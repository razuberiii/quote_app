class QuoteSharePublisher
  Result = Struct.new(:share, :url, keyword_init: true)

  def initialize(quote, document_kind: "quote", url_options: {})
    @quote = quote
    @document_kind = document_kind
    @url_options = url_options
  end

  def call
    token = QuoteShare.generate_token
    share = @quote.company.quote_shares.create!(
      quote: @quote,
      token: token,
      snapshot: QuoteSnapshotBuilder.new(@quote).as_json
    )

    quote_status = @quote.status.to_s
    next_status = Quote::AUTO_VIEW_STATUSES.include?(quote_status) || quote_status.blank? ? "sent" : quote_status
    @quote.update_columns(sent_at: @quote.sent_at || Time.current, status: next_status, updated_at: Time.current)

    Result.new(
      share: share,
      url: Rails.application.routes.url_helpers.public_quote_share_url(token, { doc: @document_kind }.merge(@url_options))
    )
  end
end
