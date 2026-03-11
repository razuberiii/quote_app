class DashboardController < CustomersController
  def index
    Quote.expire_overdue_for_company!(current_user.company_id)
    scope = current_user.company.customers.includes(:customer_tags, quotes: [ :quote_items, :template ])
    all_customers = scope.to_a

    @kpi_period = params[:kpi_period].presence_in(%w[week month]) || "week"
    @customer_metrics = build_customer_metrics(all_customers)
    @follow_up_counts = {
      today: all_customers.count(&:follow_up_due_today?),
      upcoming: all_customers.count(&:follow_up_upcoming?),
      overdue: all_customers.count(&:follow_up_overdue?),
      no_schedule: all_customers.count { |customer| customer.next_follow_up_date.blank? }
    }

    @dashboard_stats = build_dashboard_stats(all_customers, @follow_up_counts, @kpi_period)
    @decision_snapshot = build_decision_snapshot(all_customers, @kpi_period)
    @risk_snapshot = build_risk_snapshot(all_customers, @customer_metrics)
    @action_center = build_action_center(all_customers, @customer_metrics)
    @primary_action = @action_center.first
    @secondary_actions = @action_center.drop(1)
    @generated_action_items = ActionItemGenerator.new(user: current_user).call.to_a
    @system_action_items = filter_system_action_items(@generated_action_items)
    @action_required_summary = {
      total: @system_action_items.count,
      risk_customers: @risk_snapshot[:overdue] + @risk_snapshot[:stalled_high_value],
      decision_alerts: @decision_snapshot[:negotiating_stale_count],
      has_risk: (@risk_snapshot[:overdue] + @risk_snapshot[:stalled_high_value]).positive? || @decision_snapshot[:negotiating_stale_count].positive?
    }
    @deal_overview = build_deal_overview(all_customers)
    @dashboard_health_snapshot = build_dashboard_health_snapshot(all_customers)
    @recent_quotes = build_recent_quotes(all_customers)
    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(all_customers))
    @deal_radar_signals = DealRadarService.new(quotes: latest_quotes, limit: 6).call
    @quote_funnel = QuoteFunnelReportService.new(company: current_user.company).call
    @performance_report = DashboardPerformanceReportService.new(customers: all_customers).call
    @top_quoted_products = current_user.company.products.order(quoted_count: :desc, last_quoted_at: :desc).limit(5)
    @reminder_quotes = current_user.company.quotes
      .not_archived
      .latest_versions
      .includes(:customer)
      .select(&:can_send_reminder?)
      .first(5)

    # Sales Insights analytics — read-only, isolated from core signal/radar logic
    company = current_user.company
    @analytics_win_loss     = DealOutcomeAnalyticsService.new(company: company).summary
    @analytics_revision     = RevisionDepthAnalyticsService.new(company: company).win_rate_by_revision
    @analytics_channels     = ChannelUsageAnalyticsService.new(company: company).summary
    @analytics_top_products = ProductQuoteAnalyticsService.new(company: company).top_products(limit: 5)
    @analytics_silent_customers = begin
      company.customers.includes(:customer_follow_up_events).select do |customer|
        CustomerEngagementSignalService.new(customer).silent_customer?
      end.first(5)
    end
  end

  private

  def filter_system_action_items(items)
    strong_action_types = %w[win_reason_missing loss_reason_missing revision_requested]
    Array(items).select { |item| strong_action_types.include?(item.action_type.to_s) }
  end
end
