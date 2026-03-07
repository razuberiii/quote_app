class QuoteReminderSender
  def initialize(quote, document_kind: "quote", url_options: {})
    @quote = quote
    @document_kind = document_kind
    @url_options = url_options
  end

  def call
    raise ArgumentError, "Quote is not eligible for reminder" unless @quote.can_send_reminder?
    raise ArgumentError, "Customer email is missing" if @quote.customer.email.blank?

    share = @quote.quote_shares.active.order(created_at: :desc).first
    share ||= QuoteSharePublisher.new(@quote, document_kind: @document_kind, url_options: @url_options).call.share

    QuoteMailer.with(quote: @quote, share: share, reminder: true, document_kind: @document_kind, url_options: @url_options).share_email.deliver_now
    @quote.update!(reminder_count: @quote.reminder_count.to_i + 1, reminder_sent_at: Time.current)

    share
  end
end
