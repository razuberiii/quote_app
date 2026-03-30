module Dashboard
  class TodayFocusBuilder
    PRIORITY_ORDER = {
      "overdue_follow_up" => 0,
      "due_today_follow_up" => 1,
      "high_value_stalled" => 2,
      "customer_has_quote_risk" => 3,
      "long_time_no_follow_up" => 4,
      "missing_next_follow_up" => 5
    }.freeze

    PRIORITY_STYLE = {
      "overdue_follow_up" => "urgent",
      "due_today_follow_up" => "watch",
      "high_value_stalled" => "urgent",
      "customer_has_quote_risk" => "watch",
      "long_time_no_follow_up" => "watch",
      "missing_next_follow_up" => "normal"
    }.freeze

    CTA_BY_REASON = {
      "overdue_follow_up" => "go_follow_up",
      "due_today_follow_up" => "go_follow_up",
      "high_value_stalled" => "record_progress",
      "customer_has_quote_risk" => "view_customer",
      "long_time_no_follow_up" => "record_progress",
      "missing_next_follow_up" => "set_next_follow_up"
    }.freeze

    QUOTE_RISK_CATEGORY_ORDER = {
      "revision" => 0,
      "hot" => 1,
      "stalled" => 2,
      "expiring" => 3,
      "general" => 4
    }.freeze

    STRONG_QUOTE_SIGNAL_TYPES = %w[
      revision_requested
      hot_engagement_no_follow_up
      stalled_negotiation
      expiring_soon
    ].freeze

    NON_ROLLUP_SIGNAL_TYPES = %w[
      not_viewed_3d
      not_viewed_7d
      viewed_no_follow_up
    ].freeze

    def initialize(customers:, customer_metrics:, quote_signal_resolver:, quote_status_resolver:, customer_path_resolver:, high_value_customer_resolver:, stalled_customer_resolver:)
      @customers = Array(customers)
      @customer_metrics = customer_metrics || {}
      @quote_signal_resolver = quote_signal_resolver
      @quote_status_resolver = quote_status_resolver
      @customer_path_resolver = customer_path_resolver
      @high_value_customer_resolver = high_value_customer_resolver
      @stalled_customer_resolver = stalled_customer_resolver
    end

    def call
      @customers
        .filter_map { |customer| build_item(customer) }
        .sort_by { |item| sort_key(item) }
        .first(9)
    end

    private

    def build_item(customer)
      reasons = customer_reasons(customer)
      return nil if reasons.empty?

      ordered = reasons.sort_by { |reason| [ reason[:rank], reason[:sort_rank] ] }
      primary = ordered.first
      secondary = ordered.drop(1).first(2)
      cta_type = CTA_BY_REASON.fetch(primary[:type])
      cta_path = @customer_path_resolver.call(customer)
      subtitle = primary[:subtitle]
      subtitle = subtitle_with_secondary(subtitle, secondary) if secondary.any?

      {
        customer_id: customer.id,
        reason_type: primary[:type],
        priority: PRIORITY_STYLE.fetch(primary[:type], "watch"),
        priority_rank: primary[:rank],
        title: primary[:title],
        subtitle: subtitle,
        detail: subtitle,
        cta_type: cta_type,
        cta_path: cta_path,
        cta_label: I18n.t("dashboard.logic.today_focus.cta.#{cta_type}"),
        cta_method: :get,
        supporting_meta: {
          secondary_reasons: secondary.map { |reason| reason[:type] },
          quote_risk_categories: Array(primary[:quote_risk_categories])
        },
        sort_context: {
          overdue_days: overdue_days(customer),
          customer_value: customer_value(customer),
          last_activity_at: customer.last_activity_at,
          active_quote_count: active_quote_count(customer)
        }
      }
    end

    def customer_reasons(customer)
      reasons = []

      if customer.follow_up_overdue?
        reasons << {
          type: "overdue_follow_up",
          rank: PRIORITY_ORDER.fetch("overdue_follow_up"),
          sort_rank: -overdue_days(customer),
          title: I18n.t("dashboard.logic.today_focus.reason.overdue_follow_up.title", name: customer.name),
          subtitle: I18n.t("dashboard.logic.today_focus.reason.overdue_follow_up.subtitle", days: overdue_days(customer))
        }
      end

      if customer.follow_up_due_today?
        reasons << {
          type: "due_today_follow_up",
          rank: PRIORITY_ORDER.fetch("due_today_follow_up"),
          sort_rank: 0,
          title: I18n.t("dashboard.logic.today_focus.reason.due_today_follow_up.title", name: customer.name),
          subtitle: I18n.t("dashboard.logic.today_focus.reason.due_today_follow_up.subtitle")
        }
      end

      if customer.follow_up_reminders_enabled? && @high_value_customer_resolver.call(customer) && @stalled_customer_resolver.call(customer)
        reasons << {
          type: "high_value_stalled",
          rank: PRIORITY_ORDER.fetch("high_value_stalled"),
          sort_rank: -customer_value(customer),
          title: I18n.t("dashboard.logic.today_focus.reason.high_value_stalled.title", name: customer.name),
          subtitle: I18n.t("dashboard.logic.today_focus.reason.high_value_stalled.subtitle")
        }
      end

      quote_risk_categories = quote_risk_categories_for(customer)
      if quote_risk_categories.any?
        primary_category = quote_risk_categories.min_by { |category| QUOTE_RISK_CATEGORY_ORDER.fetch(category, 9) }
        reasons << {
          type: "customer_has_quote_risk",
          rank: PRIORITY_ORDER.fetch("customer_has_quote_risk"),
          sort_rank: QUOTE_RISK_CATEGORY_ORDER.fetch(primary_category, 9),
          title: I18n.t("dashboard.logic.today_focus.reason.customer_has_quote_risk.title", name: customer.name),
          subtitle: quote_risk_subtitle(primary_category, quote_risk_categories.size),
          quote_risk_categories: quote_risk_categories
        }
      end

      if customer.follow_up_reminders_enabled? && (customer.last_follow_up_date.blank? || customer.last_follow_up_date < Date.current - 14.days)
        reasons << {
          type: "long_time_no_follow_up",
          rank: PRIORITY_ORDER.fetch("long_time_no_follow_up"),
          sort_rank: days_since_last_follow_up(customer),
          title: I18n.t("dashboard.logic.today_focus.reason.long_time_no_follow_up.title", name: customer.name),
          subtitle: I18n.t("dashboard.logic.today_focus.reason.long_time_no_follow_up.subtitle")
        }
      end

      if customer.follow_up_reminders_enabled? && customer.next_follow_up_date.blank?
        reasons << {
          type: "missing_next_follow_up",
          rank: PRIORITY_ORDER.fetch("missing_next_follow_up"),
          sort_rank: 0,
          title: I18n.t("dashboard.logic.today_focus.reason.missing_next_follow_up.title", name: customer.name),
          subtitle: I18n.t("dashboard.logic.today_focus.reason.missing_next_follow_up.subtitle")
        }
      end

      reasons
    end

    def quote_risk_subtitle(primary_category, total_categories)
      category_label = I18n.t("dashboard.logic.today_focus.quote_risk_category.#{primary_category}")
      if total_categories > 1
        I18n.t("dashboard.logic.today_focus.reason.customer_has_quote_risk.subtitle_with_more", category: category_label, count: total_categories - 1)
      else
        I18n.t("dashboard.logic.today_focus.reason.customer_has_quote_risk.subtitle", category: category_label)
      end
    end

    def quote_risk_categories_for(customer)
      latest_quotes_for(customer)
        .filter_map do |quote|
          signal = @quote_signal_resolver.call(quote)
          next unless strong_quote_risk_signal?(signal)

          quote_risk_category(signal)
        end
        .uniq
    end

    def latest_quotes_for(customer)
      active_quotes = Array(customer.quotes).reject do |quote|
        (quote.respond_to?(:archived?) && quote.archived?) ||
          (quote.respond_to?(:deleted?) && quote.deleted?) ||
          (quote.respond_to?(:pi_document?) && quote.pi_document?)
      end

      active_quotes
        .group_by(&:quote_no)
        .values
        .map { |revisions| revisions.max_by(&:revision_number) }
        .select { |quote| %w[draft sent viewed negotiating].include?(@quote_status_resolver.call(quote).to_s) }
    end

    def strong_quote_risk_signal?(signal)
      return false if signal.blank?

      type = signal.type.to_s
      return true if STRONG_QUOTE_SIGNAL_TYPES.include?(type)
      return false if NON_ROLLUP_SIGNAL_TYPES.include?(type)

      %w[urgent risk].include?(signal.priority.to_s)
    end

    def quote_risk_category(signal)
      case signal.type.to_s
      when "revision_requested"
        "revision"
      when "hot_engagement_no_follow_up"
        "hot"
      when "stalled_negotiation"
        "stalled"
      when "expiring_soon"
        "expiring"
      else
        "general"
      end
    end

    def subtitle_with_secondary(primary_subtitle, secondary)
      labels = secondary.map { |reason| I18n.t("dashboard.logic.today_focus.reason_short.#{reason[:type]}") }
      [ primary_subtitle, I18n.t("dashboard.logic.today_focus.secondary_hint", reasons: labels.join("、")) ].join(" ")
    end

    def sort_key(item)
      context = item[:sort_context] || {}
      [
        item[:priority_rank],
        -context.fetch(:overdue_days, 0).to_i,
        -context.fetch(:customer_value, 0).to_f,
        context.fetch(:last_activity_at, Time.zone.at(0)).to_i,
        -context.fetch(:active_quote_count, 0).to_i,
        item[:title].to_s
      ]
    end

    def overdue_days(customer)
      return 0 unless customer.next_follow_up_date.present?

      [ (Date.current - customer.next_follow_up_date).to_i, 0 ].max
    end

    def customer_value(customer)
      @customer_metrics.fetch(customer, {}).fetch(:total_quote_amount_base_currency, 0).to_d
    end

    def days_since_last_follow_up(customer)
      return 999 if customer.last_follow_up_date.blank?

      (Date.current - customer.last_follow_up_date).to_i
    end

    def active_quote_count(customer)
      latest_quotes_for(customer).size
    end
  end
end
