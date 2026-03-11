class QuoteSignalPresenter
  include Rails.application.routes.url_helpers

  ActionCta = Struct.new(:label, :path, :method, keyword_init: true)

  def initialize(locale: I18n.locale)
    @locale = locale
  end

  def signal_cta(signal:, quote:)
    case signal.recommended_action.to_s
    when "renew_quote"
      ActionCta.new(label: signal.cta_label, path: duplicate_quote_path(quote, locale_params), method: :post)
    when "prepare_revision"
      if quote.respond_to?(:can_create_new_revision?) && quote.can_create_new_revision?
        ActionCta.new(label: signal.cta_label, path: duplicate_quote_path(quote, locale_params), method: :post)
      else
        ActionCta.new(label: signal.cta_label, path: quote_path(quote, locale_params), method: :get)
      end
    when "resend_reminder"
      if quote.respond_to?(:can_send_reminder?) && quote.can_send_reminder?
        ActionCta.new(label: signal.cta_label, path: send_reminder_quote_path(quote, locale_params), method: :post)
      else
        ActionCta.new(label: signal.cta_label, path: quote_path(quote, locale_params), method: :get)
      end
    else
      ActionCta.new(label: signal.cta_label, path: quote_path(quote, locale_params), method: :get)
    end
  end

  def action_item_cta(item)
    if item.action_type == "follow_up_due"
      customer = item.reference if item.reference.is_a?(Customer)
      customer ||= item.reference.customer if item.reference.respond_to?(:customer)
      return ActionCta.new(label: I18n.t("action_items.follow_up_due.cta"), path: customer_path(customer, locale_params), method: :get) if customer.present?
    end

    if %w[win_reason_missing loss_reason_missing].include?(item.action_type) && item.reference.is_a?(Quote)
      return ActionCta.new(
        label: I18n.t("action_items.#{item.action_type}.cta"),
        path: quote_path(item.reference, locale_params.merge(fill_reason: 1)),
        method: :get
      )
    end

    if item.reference.is_a?(Quote)
      signal = signal_for_action_item(item)
      return signal_cta(signal: signal, quote: item.reference) if signal.present?
      return ActionCta.new(label: I18n.t("dashboard.view.action_items.open"), path: quote_path(item.reference, locale_params), method: :get)
    end

    if item.reference.is_a?(Customer)
      return ActionCta.new(label: I18n.t("dashboard.view.action_items.open"), path: customer_path(item.reference, locale_params), method: :get)
    end

    ActionCta.new(label: I18n.t("dashboard.view.action_items.open"), path: "#", method: :get)
  end

  def quote_title(quote)
    customer_name = quote.customer&.name.presence || I18n.t("dashboard.logic.unknown_customer")
    quote_name = quote.custom_title.presence || quote.quote_items.ordered.first&.product&.name.presence || quote.quote_items.ordered.first&.description.presence || quote.quote_no
    "#{customer_name} · #{quote_name}"
  end

  def quote_subtitle(quote)
    quote.quote_no
  end

  private

  def signal_for_action_item(item)
    case item.action_type.to_s
    when "follow_up_due"
      QuoteSignalService::QuoteSignal.new(type: "follow_up_due", priority: "watch", recommended_action: "follow_up", label: item.message, cta_label: I18n.t("action_items.follow_up_due.cta"), metadata: {})
    when "revision_requested", "expiring_soon", "hot_engagement_no_follow_up", "viewed_no_follow_up", "not_viewed_3d", "not_viewed_7d", "stalled_negotiation"
      QuoteSignalService.new(item.reference).call
    else
      nil
    end
  end

  def locale_params
    @locale.to_s == I18n.default_locale.to_s ? {} : { locale: @locale }
  end
end
