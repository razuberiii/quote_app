module Dashboard
  class QuoteTodoBuilder
    STRONG_REASON_TYPES = %w[
      revision_requested
      won_reason_missing
      lost_reason_missing
      draft_pending_send
    ].freeze

    PRIORITY_ORDER = {
      "revision_requested" => 0,
      "won_reason_missing" => 1,
      "lost_reason_missing" => 1,
      "draft_pending_send" => 2,
      "hot_engagement_no_follow_up" => 3,
      "stalled_negotiation" => 4,
      "expiring_soon" => 5,
      "viewed_no_follow_up" => 6,
      "not_viewed_7d" => 7,
      "not_viewed_3d" => 8
    }.freeze

    PRIORITY_STYLE = {
      "revision_requested" => "urgent",
      "won_reason_missing" => "urgent",
      "lost_reason_missing" => "urgent",
      "draft_pending_send" => "watch",
      "hot_engagement_no_follow_up" => "urgent",
      "stalled_negotiation" => "watch",
      "expiring_soon" => "urgent",
      "viewed_no_follow_up" => "watch",
      "not_viewed_7d" => "watch",
      "not_viewed_3d" => "watch"
    }.freeze

    CTA_BY_REASON = {
      "revision_requested" => "handle_revision",
      "won_reason_missing" => "fill_reason",
      "lost_reason_missing" => "fill_reason",
      "draft_pending_send" => "send_quote",
      "hot_engagement_no_follow_up" => "go_follow_up",
      "stalled_negotiation" => "go_follow_up",
      "expiring_soon" => "open_quote",
      "viewed_no_follow_up" => "go_follow_up",
      "not_viewed_7d" => "go_follow_up",
      "not_viewed_3d" => "go_follow_up"
    }.freeze

    SENT_WEAK_REASON_TYPES = %w[not_viewed_3d not_viewed_7d expiring_soon].freeze
    ACTIVE_WEAK_REASON_TYPES = %w[viewed_no_follow_up hot_engagement_no_follow_up stalled_negotiation expiring_soon].freeze

    def initialize(quotes:, today_focus_items:, quote_signal_resolver:, quote_status_resolver:, quote_path_resolver:, quote_display_name_resolver:)
      @quotes = Array(quotes)
      @today_focus_items = Array(today_focus_items)
      @quote_signal_resolver = quote_signal_resolver
      @quote_status_resolver = quote_status_resolver
      @quote_path_resolver = quote_path_resolver
      @quote_display_name_resolver = quote_display_name_resolver
    end

    def call
      absorb_context = absorb_context_by_customer
      deduped = {}

      @quotes.each do |quote|
        item = build_item(quote, absorb_context)
        next if item.blank?

        existing = deduped[quote.id]
        if existing.blank? || item[:priority_rank] < existing[:priority_rank]
          deduped[quote.id] = item
        end
      end

      deduped
        .values
        .sort_by { |item| [ item[:priority_rank], -(item[:updated_at] || Time.zone.at(0)).to_i ] }
        .first(10)
    end

    private

    def build_item(quote, absorb_context)
      status = @quote_status_resolver.call(quote).to_s
      signal = @quote_signal_resolver.call(quote)
      reason_type = resolve_reason_type(quote, status, signal)
      return nil if reason_type.blank?

      return nil if weak_reason_hidden?(quote, reason_type, absorb_context)

      cta_type = CTA_BY_REASON.fetch(reason_type)
      cta_label = I18n.t("dashboard.logic.quote_todo.cta.#{cta_type}")
      subtitle = I18n.t("dashboard.logic.quote_todo.reason.#{reason_type}.subtitle")
      quote_path = @quote_path_resolver.call(quote)

      {
        quote_id: quote.id,
        customer_id: quote.customer_id,
        reason_type: reason_type,
        priority: PRIORITY_STYLE.fetch(reason_type, "watch"),
        priority_rank: PRIORITY_ORDER.fetch(reason_type, 99),
        title: @quote_display_name_resolver.call(quote),
        subtitle: subtitle,
        cta_type: cta_type,
        cta_path: quote_path,
        supporting_meta: {
          quote_no: quote.quote_no,
          status: status
        },
        quote: quote,
        quote_no: quote.quote_no,
        display_name: @quote_display_name_resolver.call(quote),
        customer_name: quote.customer&.name.presence || I18n.t("dashboard.logic.unknown_customer"),
        status: status,
        signal: subtitle,
        next_action: {
          label: cta_label,
          path: quote_path,
          method: :get,
          style: cta_style_for(cta_type)
        },
        updated_at: quote.updated_at
      }
    end

    def resolve_reason_type(quote, status, signal)
      return "won_reason_missing" if status == "won" && quote.win_reason.blank?
      return "lost_reason_missing" if status == "lost" && quote.loss_reason.blank?
      return "revision_requested" if signal&.type.to_s == "revision_requested"
      return "draft_pending_send" if status == "draft"

      signal_type = signal&.type.to_s
      if status == "sent" && SENT_WEAK_REASON_TYPES.include?(signal_type)
        return signal_type
      end
      if %w[viewed negotiating].include?(status) && ACTIVE_WEAK_REASON_TYPES.include?(signal_type)
        return signal_type
      end

      nil
    end

    def weak_reason_hidden?(quote, reason_type, absorb_context)
      return false if STRONG_REASON_TYPES.include?(reason_type)

      categories = absorb_context[quote.customer_id]
      return false if categories.blank?

      case reason_type
      when "stalled_negotiation"
        categories.include?("stalled")
      when "hot_engagement_no_follow_up"
        categories.include?("hot")
      when "expiring_soon", "not_viewed_7d", "not_viewed_3d"
        categories.include?("expiring")
      when "viewed_no_follow_up"
        categories.any? { |category| %w[hot stalled].include?(category) }
      else
        false
      end
    end

    def absorb_context_by_customer
      @today_focus_items.each_with_object({}) do |item, memo|
        next unless item[:reason_type].to_s == "customer_has_quote_risk"

        categories = Array(item.dig(:supporting_meta, :quote_risk_categories)).map(&:to_s)
        next if categories.empty?

        memo[item[:customer_id]] = categories
      end
    end

    def cta_style_for(cta_type)
      case cta_type
      when "fill_reason"
        "is-attention"
      when "handle_revision", "go_follow_up"
        "is-primary"
      when "send_quote"
        "is-watch"
      else
        "is-neutral"
      end
    end
  end
end
