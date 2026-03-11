class FollowUpAssistantService
  ACTIVE_WORKFLOW_STATES = %w[draft sent viewed negotiating].freeze

  def initialize(customer:, latest_quote: nil, quote_view_status: nil, quote_expiry_status: nil, quote_signal: nil, locale: nil, url_options: {})
    @customer = customer
    @latest_quote = latest_quote
    @quote_view_status = quote_view_status
    @quote_expiry_status = quote_expiry_status
    @quote_signal = quote_signal
    @locale = locale
    @url_options = url_options || {}
  end

  def call
    I18n.with_locale(resolved_locale) do
      message = I18n.t("follow_up.assistant.messages.#{message_key}", name: customer_name)
      share_url = relevant_share_url
      return message if share_url.blank?

      [
        message,
        "",
        I18n.t("follow_up.message.quote_link_intro"),
        I18n.t("follow_up.message.quote_link_label"),
        share_url
      ].join("\n")
    end
  end

  def relevant_quote
    @relevant_quote ||= begin
      candidates = latest_revision_quotes
      latest_active_quote(candidates) ||
        latest_quote_with_public_share(candidates) ||
        latest_quote(candidates) ||
        @latest_quote
    end
  end

  private

  def customer_name
    @customer.contact_name.presence || @customer.name
  end

  def message_key
    signal_key = signal_message_key
    return signal_key if signal_key.present?

    return "expired" if expired_quote?
    return "viewed" if viewed_quote?
    return "not_viewed" if not_viewed_quote?

    "generic"
  end

  def signal_message_key
    signal = resolved_quote_signal
    return nil if signal.blank?

    case signal.type.to_s
    when "hot_engagement_no_follow_up"
      "hot_engagement_no_follow_up"
    when "expiring_soon"
      "expiring_soon"
    when "not_viewed_3d", "not_viewed_7d"
      "not_viewed"
    when "viewed_no_follow_up", "stalled_negotiation"
      "viewed"
    else
      nil
    end
  end

  def expired_quote?
    @quote_expiry_status.to_s == "expired" || relevant_quote&.workflow_state == "expired" || relevant_quote&.expired_by_date?
  end

  def viewed_quote?
    @quote_view_status.to_s == "viewed" || relevant_quote&.viewed_at.present? || relevant_quote&.workflow_state == "viewed"
  end

  def not_viewed_quote?
    return true if @quote_view_status.to_s == "not_viewed"

    relevant_quote.present? && relevant_quote.sent_at.present? && relevant_quote.viewed_at.blank?
  end

  def latest_revision_quotes
    return [] unless @customer&.persisted?

    quotes = @customer.quotes.not_archived.includes(:quote_shares, :template).to_a
    groups = quotes.group_by { |quote| quote.quote_no.presence || "__quote_#{quote.id}" }
    groups.values.map { |revisions| revisions.max_by { |quote| [ quote.revision_number.to_i, quote.updated_at.to_i ] } }
  end

  def resolved_quote_signal
    @resolved_quote_signal ||= begin
      return @quote_signal if @quote_signal.present?
      return nil if relevant_quote.blank?

      QuoteSignalService.new(relevant_quote).call
    end
  end

  def resolved_locale
    return @locale if @locale.present?

    template = relevant_quote&.template || @latest_quote&.template || @customer&.company&.quote_template_or_default
    template&.output_locale_for(:webview).presence || I18n.locale
  end

  def latest_active_quote(candidates)
    candidates
      .select { |quote| ACTIVE_WORKFLOW_STATES.include?(quote.workflow_state) }
      .max_by { |quote| quote.updated_at.to_i }
  end

  def latest_quote_with_public_share(candidates)
    candidates
      .select { |quote| latest_active_share_for(quote).present? }
      .max_by { |quote| quote.updated_at.to_i }
  end

  def latest_quote(candidates)
    candidates.max_by { |quote| quote.updated_at.to_i }
  end

  def relevant_share_url
    share = latest_active_share_for(relevant_quote_for_share)
    return nil if share.blank?

    Rails.application.routes.url_helpers.public_quote_share_url(
      share.token,
      default_url_options.merge(@url_options)
    )
  rescue StandardError
    nil
  end

  def relevant_quote_for_share
    @relevant_quote_for_share ||= begin
      candidates = latest_revision_quotes
      latest_active_quote(candidates.select { |quote| latest_active_share_for(quote).present? }) ||
        latest_quote_with_public_share(candidates) ||
        @latest_quote
    end
  end

  def latest_active_share_for(quote)
    return nil if quote.blank?

    if quote.association(:quote_shares).loaded?
      quote.quote_shares.select { |share| share.expires_at.blank? || share.expires_at > Time.current }.max_by(&:created_at)
    else
      quote.quote_shares.active.order(created_at: :desc).first
    end
  end

  def default_url_options
    configured = Rails.application.config.action_mailer.default_url_options || {}
    host = configured[:host].presence || ENV["APP_HOST"].presence || "localhost"
    protocol = configured[:protocol].presence || (host.to_s.include?("localhost") ? "http" : "https")

    { host: host, protocol: protocol }
  end
end
