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
    @action_required_summary = {
      total: @action_center.count { |item| %w[urgent watch].include?(item[:priority]) },
      risk_customers: @risk_snapshot[:overdue] + @risk_snapshot[:stalled_high_value],
      decision_alerts: @decision_snapshot[:negotiating_stale_count],
      has_risk: (@risk_snapshot[:overdue] + @risk_snapshot[:stalled_high_value]).positive? || @decision_snapshot[:negotiating_stale_count].positive?
    }
    @deal_overview = build_deal_overview(all_customers)
    @dashboard_health_snapshot = build_dashboard_health_snapshot(all_customers)
    @recent_quotes = build_recent_quotes(all_customers)
    @generated_action_items = ActionItemGenerator.new(user: current_user).call.to_a
    @quote_funnel = QuoteFunnelReportService.new(company: current_user.company).call
    @performance_report = DashboardPerformanceReportService.new(customers: all_customers).call
    @top_quoted_products = current_user.company.products.order(quoted_count: :desc, last_quoted_at: :desc).limit(5)
    @reminder_quotes = current_user.company.quotes
      .not_archived
      .latest_versions
      .includes(:customer)
      .select(&:can_send_reminder?)
      .first(5)
  end
end
