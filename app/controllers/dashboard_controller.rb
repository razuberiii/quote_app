class DashboardController < CustomersController
  def index
    Quote.expire_overdue_for_company!(current_user.company_id)
    @onboarding = build_onboarding_progress
    @onboarding_complete = @onboarding.values.all?
    @show_onboarding = !current_user.dismissed_onboarding? && !@onboarding_complete
    @quick_create_quote_path = resolve_quick_create_quote_path

    scope = current_user.company.customers.includes(:customer_tags, quotes: [ :quote_items, :template ])
    all_customers = dashboard_customers_for_user(scope.to_a)
    @engagement_states = all_customers.index_with(&:effective_engagement_state)

    @kpi_period = params[:kpi_period].presence_in(%w[week month]) || "week"
    @high_value_currency = current_user.company.default_currency.to_s.upcase.presence || "USD"
    @customer_metrics = build_customer_metrics(all_customers, base_currency: @high_value_currency)
    @follow_up_counts = {
      today: all_customers.count(&:follow_up_due_today?),
      upcoming: all_customers.count(&:follow_up_upcoming?),
      overdue: all_customers.count(&:follow_up_overdue?),
      no_schedule: all_customers.count { |customer| customer.follow_up_reminders_enabled? && customer.next_follow_up_date.blank? }
    }

    @dashboard_stats = build_dashboard_stats(all_customers, @follow_up_counts, @kpi_period, @engagement_states)
    @decision_snapshot = build_decision_snapshot(all_customers, @kpi_period)
    @risk_snapshot = build_risk_snapshot(all_customers, @customer_metrics, @engagement_states)
    @action_center = Dashboard::TodayFocusBuilder.new(
      customers: all_customers,
      customer_metrics: @customer_metrics,
      quote_signal_resolver: ->(quote) { quote_signal_for(quote) },
      quote_status_resolver: ->(quote) { quote_display_status(quote) },
      customer_path_resolver: ->(customer) { customer_path(customer) },
      high_value_customer_resolver: ->(customer) { high_value_customer?(customer, @customer_metrics) },
      stalled_customer_resolver: ->(customer) { stalled_customer?(customer) }
    ).call
    @primary_action = @action_center.first
    @secondary_actions = @action_center.drop(1)
    @deal_overview = build_deal_overview(all_customers)
    @dashboard_health_snapshot = build_dashboard_health_snapshot(all_customers)
    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(all_customers))
    visible_quotes = latest_quotes.select { |quote| dashboard_quote_visible_for_user?(quote) }
    @quote_todo_entries = Dashboard::QuoteTodoBuilder.new(
      quotes: visible_quotes,
      today_focus_items: @action_center,
      quote_signal_resolver: ->(quote) { quote_signal_for(quote) },
      quote_status_resolver: ->(quote) { quote_display_status(quote) },
      quote_path_resolver: ->(quote) { quote_path(quote) },
      quote_display_name_resolver: ->(quote) { quote_display_name(quote) }
    ).call
    @quote_funnel = QuoteFunnelReportService.new(company: current_user.company).call
    @top_quoted_products = current_user.company.products.order(quoted_count: :desc, last_quoted_at: :desc).limit(5)
    # Sales Insights analytics — read-only, isolated from core signal/radar logic
    company = current_user.company
    @analytics_win_loss     = DealOutcomeAnalyticsService.new(company: company).summary
    @analytics_win_loss_top = build_win_loss_top_summary(@analytics_win_loss, top_n: 5)
    @analytics_revision     = RevisionDepthAnalyticsService.new(company: company).win_rate_by_revision
    @analytics_channels     = ChannelUsageAnalyticsService.new(company: company).summary
    @analytics_top_products = ProductQuoteAnalyticsService.new(company: company).top_products(limit: 5)
    @dashboard_core_metrics = build_dashboard_core_metrics(@dashboard_stats, @follow_up_counts)
    @dashboard_activity_mix = build_dashboard_activity_mix(@follow_up_counts)
  end

  private

  def dashboard_customers_for_user(customers)
    return customers unless Customer.internal_owner_enabled?

    customers.select do |customer|
      owner_id = customer.respond_to?(:internal_owner_id) ? customer.internal_owner_id : nil
      if owner_id.present?
        owner_id == current_user.id
      else
        current_user.company_owner? || current_user.company_admin?
      end
    end
  end

  def dashboard_quote_visible_for_user?(quote)
    customer = quote.customer
    return true if customer.blank?
    return true unless Customer.internal_owner_enabled?

    owner_id = customer.respond_to?(:internal_owner_id) ? customer.internal_owner_id : nil
    if owner_id.present?
      owner_id == current_user.id
    else
      current_user.company_owner? || current_user.company_admin?
    end
  end

  def build_onboarding_progress
    company = current_user.company

    {
      account_profile: account_profile_complete?,
      company_profile: company_profile_complete?,
      customer: company.customers.exists?,
      product: company.products.exists?,
      quote: company.quotes.exists?,
      shared: company.quote_shares.exists?,
      viewed: QuoteViewEvent.joins(:quote_share).where(quote_shares: { company_id: company.id }).exists?
    }
  end

  def account_profile_complete?
    current_user.full_name.to_s.strip.present? &&
      current_user.contact_phone.to_s.strip.present? &&
      current_user.time_zone.to_s.strip.present? &&
      current_user.avatar.attached?
  end

  def company_profile_complete?
    return true unless current_user.can_manage_templates?

    company = current_user.company
    company.name.to_s.strip.present? &&
      company.phone.to_s.strip.present? &&
      company.brand_color.to_s.strip.present? &&
      company.logo.attached?
  end

  def resolve_quick_create_quote_path
    customers = current_user.company.customers.select(:id).limit(2).to_a
    return new_customer_quote_path(customers.first) if customers.one?

    customers_path
  end

  def build_win_loss_top_summary(summary, top_n: 5)
    {
      wins: compress_reason_rows(Array(summary[:win_reasons]), top_n: top_n, category: :win),
      losses: compress_reason_rows(Array(summary[:loss_reasons]), top_n: top_n, category: :loss)
    }
  end

  def compress_reason_rows(rows, top_n:, category:)
    ordered_rows = rows.sort_by { |row| -row[:count].to_i }
    top_rows = ordered_rows.first(top_n)
    remaining = ordered_rows.drop(top_n)
    other_count = remaining.sum { |row| row[:count].to_i }
    total = ordered_rows.sum { |row| row[:count].to_i }

    if other_count.positive?
      other_label = I18n.t("analytics.reason_labels.#{category}.other", default: I18n.t("analytics.reason_labels.win.other", default: "Other"))
      pct = total.zero? ? 0 : ((other_count.to_f / total) * 100).round
      top_rows << { label: other_label, count: other_count, pct: pct }
    end

    { rows: top_rows, total: total }
  end

  def build_dashboard_core_metrics(dashboard_stats, follow_up_counts)
    risk_count = follow_up_counts[:overdue].to_i + follow_up_counts[:today].to_i + follow_up_counts[:no_schedule].to_i

    [
      {
        label: I18n.t("dashboard.view.index.open_deals"),
        value: dashboard_stats[:open_deals][:value],
        detail: dashboard_stats[:open_deals][:trend_text]
      },
      {
        label: I18n.t("dashboard.view.index.quotes_this_period", period: (@kpi_period == "month" ? I18n.t("dashboard.view.index.period_month") : I18n.t("dashboard.view.index.period_week"))),
        value: dashboard_stats[:quotes_this_week][:value],
        detail: dashboard_stats[:quotes_this_week][:trend_text]
      },
      {
        label: I18n.t("dashboard.view.index.pending_followups"),
        value: dashboard_stats[:pending_follow_ups][:value],
        detail: dashboard_stats[:pending_follow_ups][:trend_text]
      },
      {
        label: I18n.t("dashboard.view.index.followup_risk"),
        value: risk_count,
        detail: I18n.t("dashboard.view.index.followup_risk_detail", count: risk_count)
      }
    ]
  end

  def build_dashboard_activity_mix(follow_up_counts)
    total = follow_up_counts.values.sum
    total = 1 if total.zero?

    segments = [
      { key: :overdue, label: I18n.t("dashboard.view.index.mix_overdue"), count: follow_up_counts[:overdue].to_i, tone: "danger" },
      { key: :today, label: I18n.t("dashboard.view.index.mix_due_today"), count: follow_up_counts[:today].to_i, tone: "watch" },
      { key: :upcoming, label: I18n.t("dashboard.view.index.mix_upcoming"), count: follow_up_counts[:upcoming].to_i, tone: "neutral" },
      { key: :no_schedule, label: I18n.t("dashboard.view.index.mix_no_schedule"), count: follow_up_counts[:no_schedule].to_i, tone: "muted" }
    ]

    segments.map do |segment|
      segment.merge(percent: ((segment[:count].to_f / total) * 100).round)
    end
  end
end
