class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy mark_follow_up schedule_follow_up]
  before_action :set_customer_form_collections, only: %i[new create edit update]

  def index
    Quote.expire_overdue_for_company!(current_user.company_id)
    scope = current_user.company.customers.search(params[:query]).includes(:customer_tags, quotes: [ :quote_items, :template ])
    all_customers = scope.to_a

    @kpi_period = params[:kpi_period].presence_in(%w[week month]) || "week"
    @customer_metrics = build_customer_metrics(all_customers)
    @list_filter = params[:list_filter].presence_in(%w[all high_value at_risk]) || "all"
    filtered_customers = apply_list_filter(all_customers, @customer_metrics, @list_filter)
    @follow_up_filter = params[:follow_up_filter].presence_in(%w[all today upcoming overdue no_schedule]) || "all"
    filtered_customers = apply_follow_up_filter(filtered_customers, @follow_up_filter)

    @sort_key = params[:sort].presence_in(%w[total_quote_amount total_won_amount win_rate next_follow_up]) || "next_follow_up"
    @sort_direction = params[:direction].presence_in(%w[asc desc]) || default_sort_direction(@sort_key)
    @customers = sort_customers(filtered_customers, @customer_metrics, @sort_key, @sort_direction)

    @search_query = params[:query]
    @has_any_customers = all_customers.any?
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
    @recent_quotes = build_recent_quotes(all_customers)
    @customer_row_signals = build_customer_row_signals(@customers, @customer_metrics)
  end

  def show
    Quote.expire_overdue_for_company!(current_user.company_id)
    quote_groups = @customer.quotes.includes(:quote_items, :quote_shares).order(:quote_no, :revision_number).group_by(&:quote_no)
    @quote_cards = quote_groups.values.map { |revisions| build_quote_card(revisions) }
    @quote_cards.sort_by! { |card| card[:updated_at] || Time.at(0) }.reverse!

    @quote_status_filter = params[:quote_status].presence_in(%w[all draft sent viewed negotiating won lost expired]) || "all"
    @quote_query = params[:quote_query].to_s.strip
    @quote_sort = params[:quote_sort].presence_in(%w[priority newest amount_high status]) || "priority"
    status_filtered_cards =
      if @quote_status_filter == "all"
        @quote_cards
      else
        @quote_cards.select { |card| card[:display_status] == @quote_status_filter }
      end

    status_filtered_cards.each do |card|
      card[:push_signal] = quote_push_signal(card[:quote], card[:display_status], @customer)
    end
    query_filtered_cards = filter_quote_cards_by_query(status_filtered_cards, @quote_query)
    sorted_query_cards = sort_quote_cards(query_filtered_cards, @quote_sort)
    @quote_view = params[:quote_view].presence_in(%w[active recent all]) || "active"
    @active_quote_cards = sorted_query_cards.select { |card| actionable_quote_card?(card, @customer) }
    @recent_quote_cards = sorted_query_cards.sort_by { |card| -(card[:updated_at] || Time.zone.at(0)).to_i }.first(10)
    @all_quote_cards = sorted_query_cards
    @active_quote_breakdown = {
      "draft" => @active_quote_cards.count { |card| card[:display_status] == "draft" },
      "sent" => @active_quote_cards.count { |card| card[:display_status] == "sent" },
      "viewed" => @active_quote_cards.count { |card| card[:display_status] == "viewed" },
      "negotiating" => @active_quote_cards.count { |card| card[:display_status] == "negotiating" }
    }
    @filtered_quote_cards =
      case @quote_view
      when "recent"
        @recent_quote_cards
      when "all"
        page_data = paginate_cards(@all_quote_cards, params[:quotes_page], per_page: 12)
        @quotes_page = page_data[:page]
        @quotes_total_pages = page_data[:total_pages]
        page_data[:items]
      else
        @active_quote_cards.first(5)
      end

    @quote_summary = {
      total_count: @quote_cards.count,
      won_count: @quote_cards.count { |card| card[:display_status] == "won" },
      lost_count: @quote_cards.count { |card| card[:display_status] == "lost" },
      draft_count: @quote_cards.count { |card| card[:display_status] == "draft" },
      sent_count: @quote_cards.count { |card| card[:display_status] == "sent" },
      viewed_count: @quote_cards.count { |card| card[:display_status] == "viewed" },
      negotiating_count: @quote_cards.count { |card| card[:display_status] == "negotiating" },
      expired_count: @quote_cards.count { |card| card[:display_status] == "expired" },
      won_amounts_by_currency: summarize_amount_by_currency(@quote_cards, "won"),
      lost_amounts_by_currency: summarize_amount_by_currency(@quote_cards, "lost"),
      avg_discount_pct: average_discount_percentage(@quote_cards)
    }

    latest_quote = @quote_cards.max_by { |card| card[:updated_at] || Time.at(0) }
    @customer_summary = {
      total_quotes: @quote_cards.count,
      latest_quote_at: latest_quote&.dig(:updated_at),
      sales_stage: @customer.status_label,
      last_follow_up_at: @customer.last_follow_up_date
    }
    @follow_up_tasks = build_follow_up_tasks(@customer, @quote_cards)
    @visible_follow_up_tasks = @follow_up_tasks.first(2)
    @hidden_follow_up_tasks = @follow_up_tasks.drop(2)
    @timeline_events = build_customer_timeline(@customer, @quote_cards)
    @high_signal_timeline_events = @timeline_events.select { |event| event[:category] == "high_signal" }
    @system_timeline_events = @timeline_events.select { |event| event[:category] == "system_activity" }
    @visible_high_signal_timeline_events = @high_signal_timeline_events.first(7)
    @hidden_high_signal_timeline_events = @high_signal_timeline_events.drop(7)
    @latest_customer_signal_at = @high_signal_timeline_events.first&.dig(:at)
    @customer_engagement = customer_engagement_state(@customer, @latest_customer_signal_at)
    @days_since_last_signal = @latest_customer_signal_at.present? ? (Date.current - @latest_customer_signal_at.to_date).to_i : nil
    @days_until_follow_up = @customer.next_follow_up_date.present? ? (@customer.next_follow_up_date - Date.current).to_i : nil
    @follow_up_text = follow_up_text_for(@customer)
    @follow_up_primary_action = follow_up_primary_action_for(@customer)
  end

  def new
    @customer = current_user.company.customers.new
    @customer.internal_owner ||= current_user if Customer.internal_owner_enabled?
  end

  def create
    unless current_user.can_create_customer?
      redirect_to customers_path, alert: "Free plan limit reached: #{current_user.customer_count_for_limit}/#{User::FREE_CUSTOMER_LIMIT} customers used." and return
    end

    @customer = current_user.company.customers.new
    @customer.assign_attributes(customer_params)
    apply_custom_tags(@customer)
    @customer.internal_owner ||= current_user if Customer.internal_owner_enabled?

    if @customer.save
      redirect_to @customer
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @customer.assign_attributes(customer_params)
    apply_custom_tags(@customer)

    if @customer.save
      @customer.avatar.purge_later if remove_avatar_requested?
      redirect_to @customer
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path
  end

  def mark_follow_up
    @customer.mark_followed_today!
    redirect_to @customer, notice: "Follow-up marked for today. Next follow-up scheduled at #{@customer.next_follow_up_date.strftime('%Y-%m-%d')}"
  end

  def schedule_follow_up
    days = params[:days].to_i
    allowed_days = [ 0, 3, 7, 14, 30 ]
    unless allowed_days.include?(days)
      redirect_to @customer, alert: "Unsupported follow-up interval." and return
    end

    target_date = Date.current + days.days
    if @customer.update(next_follow_up_date: target_date)
      label = days.zero? ? "today" : "in #{days} days"
      redirect_to @customer, notice: "Next follow-up scheduled for #{target_date.strftime('%Y-%m-%d')} (#{label})."
    else
      redirect_to @customer, alert: @customer.errors.full_messages.to_sentence
    end
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:id])
  end

  def customer_params
    permitted_keys = [
      :name,
      :country,
      :address,
      :contact_name,
      :email,
      :phone,
      :status,
      :customer_level,
      :customer_source,
      :payment_terms,
      :main_product_interest,
      :estimated_annual_volume,
      :timezone,
      :next_follow_up_date,
      :last_follow_up_date,
      :notes,
      :avatar
    ]
    permitted_keys << :internal_owner_id if Customer.internal_owner_enabled?
    permitted = params.require(:customer).permit(*permitted_keys, customer_tag_ids: [])
    permitted[:customer_tag_ids] = Array(permitted[:customer_tag_ids]).reject(&:blank?)
    permitted
  end

  def set_customer_form_collections
    @owner_users =
      if Customer.internal_owner_enabled?
        current_user.company.users.order(Arel.sql("COALESCE(NULLIF(full_name, ''), email) ASC"))
      else
        []
      end
    CustomerTag.ensure_presets_for(current_user.company)
    @available_tags = current_user.company.customer_tags.ordered
  end

  def apply_custom_tags(customer)
    custom_names = Array(params.dig(:customer, :new_tag_names)).map { |name| name.to_s.split(",") }.flatten
    custom_names.concat(customer_custom_tags_input.to_s.split(","))
    custom_names = custom_names.map { |name| name.strip.gsub(/\s+/, " ") }.reject(&:blank?).uniq
    return if custom_names.empty?

    tag_ids = custom_names.map do |name|
      current_user.company.customer_tags.find_or_create_by!(name: name).id
    end
    customer.customer_tag_ids = (customer.customer_tag_ids + tag_ids).uniq
  end

  def customer_custom_tags_input
    params.dig(:customer, :custom_tags_input)
  end

  def remove_avatar_requested?
    params.dig(:customer, :remove_avatar).to_s == "1" && params.dig(:customer, :avatar).blank?
  end

  def build_quote_card(revisions)
    ordered = revisions.sort_by(&:revision_number)
    latest = ordered.last
    previous = ordered[-2]
    original = ordered.first

    current_total = latest.grand_total.to_d
    original_total = original.grand_total.to_d
    diff_amount = current_total - original_total
    diff_pct = original_total.positive? ? ((diff_amount / original_total) * 100).round(2) : nil

    trend = if previous.present?
      previous_total = previous.grand_total.to_d
      if current_total > previous_total
        :up
      elsif current_total < previous_total
        :down
      else
        :flat
      end
    else
      :flat
    end

    {
      quote: latest,
      quote_no: latest.quote_no,
      title: latest.title,
      revision: latest.revision_number,
      display_status: quote_display_status(latest),
      current_total: current_total,
      currency: latest.currency.to_s.upcase.presence || "USD",
      original_total: original_total,
      diff_amount: diff_amount,
      diff_pct: diff_pct,
      changed_from_original: ordered.size > 1 && diff_amount.nonzero?,
      trend: trend,
      updated_at: latest.updated_at
    }
  end

  def quote_display_status(quote)
    raw_status = quote.status.to_s.downcase
    raw_status = "draft" if raw_status == "pending"
    return "won" if quote.accepted_at.present?
    raw_status = "negotiating" if raw_status == "negotiating" || quote.changes_requested_at.present?
    return "expired" if Quote::OPEN_STATUSES.include?(raw_status) && quote.valid_until.present? && quote.valid_until < Date.current

    raw_status.presence || "draft"
  end

  def average_discount_percentage(cards)
    percentages = cards.filter_map do |card|
      quote = card[:quote]
      subtotal = quote.subtotal.to_d
      next if subtotal <= 0

      ((quote.discount_amount.to_d / subtotal) * 100)
    end

    return 0 if percentages.empty?

    (percentages.sum / percentages.size).round(2)
  end

  def build_customer_metrics(customers)
    customers.index_with do |customer|
      quotes = customer.quotes
      total_quote_amount = quotes.sum { |quote| quote.grand_total.to_d }
      won_quotes = quotes.select { |quote| quote.status == "won" }
      total_won_amount = won_quotes.sum { |quote| quote.grand_total.to_d }
      quote_count = quotes.count
      won_count = won_quotes.count
      win_rate = quote_count.positive? ? ((won_count.to_d / quote_count) * 100).round(2) : 0

      {
        total_quote_amount: total_quote_amount,
        total_won_amount: total_won_amount,
        quote_count: quote_count,
        won_count: won_count,
        win_rate: win_rate
      }
    end
  end

  def apply_list_filter(customers, metrics, filter)
    case filter
    when "high_value"
      return [] if customers.empty?

      top_n = [ (customers.size * 0.2).ceil, 1 ].max
      ranked = customers.sort_by { |customer| metrics.fetch(customer)[:total_quote_amount].to_d }.reverse
      ranked.first(top_n)
    when "at_risk"
      customers.select(&:follow_up_overdue?)
    else
      customers
    end
  end

  def apply_follow_up_filter(customers, filter)
    case filter
    when "today"
      customers.select(&:follow_up_due_today?)
    when "upcoming"
      customers.select(&:follow_up_upcoming?)
    when "overdue"
      customers.select(&:follow_up_overdue?)
    when "no_schedule"
      customers.select { |customer| customer.next_follow_up_date.blank? }
    else
      customers
    end
  end

  def sort_customers(customers, metrics, sort_key, direction)
    sorted = case sort_key
    when "total_quote_amount"
      customers.sort_by { |customer| metrics.fetch(customer)[:total_quote_amount].to_d }
    when "total_won_amount"
      customers.sort_by { |customer| metrics.fetch(customer)[:total_won_amount].to_d }
    when "win_rate"
      customers.sort_by { |customer| metrics.fetch(customer)[:win_rate].to_d }
    when "next_follow_up"
      customers.sort_by { |customer| [ customer_risk_rank(customer), customer.next_follow_up_date || Date.new(9999, 12, 31) ] }
    else
      customers
    end

    direction == "desc" ? sorted.reverse : sorted
  end

  def default_sort_direction(sort_key)
    sort_key == "next_follow_up" ? "asc" : "desc"
  end

  def latest_quotes_from_collection(quotes)
    quotes.group_by(&:quote_no).values.map { |revisions| revisions.max_by(&:revision_number) }
  end

  def build_dashboard_stats(customers, follow_up_counts, period)
    all_quotes = customers.flat_map(&:quotes)
    today = Date.current
    reference_date = period == "month" ? today.prev_month : today - 7.days

    open_deals_now = open_deals_count_at(all_quotes, today)
    open_deals_previous = open_deals_count_at(all_quotes, reference_date)

    this_period_start = period == "month" ? today.beginning_of_month : today.beginning_of_week
    last_period_start = period == "month" ? (this_period_start << 1) : (this_period_start - 7.days)
    this_period_count = all_quotes.count do |quote|
      created_on = quote.created_at&.to_date
      created_on.present? && created_on >= this_period_start
    end
    last_period_count = all_quotes.count do |quote|
      created_on = quote.created_at&.to_date
      created_on.present? && created_on >= last_period_start && created_on < this_period_start
    end

    pending_follow_ups_now = follow_up_counts[:today] + follow_up_counts[:upcoming] + follow_up_counts[:overdue]
    pending_follow_ups_previous = customers.count { |customer| pending_follow_up_for_reference?(customer, reference_date, period) }

    {
      open_deals: build_kpi_value(open_deals_now, open_deals_previous, period, kind: :open_deals),
      quotes_this_week: build_kpi_value(this_period_count, last_period_count, period, kind: :throughput),
      pending_follow_ups: build_kpi_value(pending_follow_ups_now, pending_follow_ups_previous, period, kind: :risk)
    }
  end

  def build_deal_overview(customers)
    all_quotes = customers.flat_map(&:quotes)
    quote_groups = all_quotes.group_by(&:quote_no)
    latest_quotes = latest_quotes_from_collection(all_quotes)

    top_item_name, _ = latest_quotes
      .flat_map(&:quote_items)
      .map { |item| item.description.to_s.strip.presence }
      .compact
      .tally
      .max_by { |_, count| count }

    closed_cycle_days = quote_groups.values.filter_map do |revisions|
      first = revisions.min_by(&:revision_number)
      latest = revisions.max_by(&:revision_number)
      next unless first&.created_at && latest&.updated_at
      next unless %w[won lost].include?(latest.status)

      (latest.updated_at.to_date - first.created_at.to_date).to_i
    end

    revised_count = quote_groups.values.count { |revisions| revisions.size > 1 }
    total_groups = quote_groups.size

    quotation_count = latest_quotes.count do |quote|
      template_kind = quote.template&.document_kind.to_s
      template_kind.blank? || template_kind == "quotation"
    end
    pi_count = latest_quotes.count { |quote| quote.template&.document_kind == "proforma_invoice" }
    total_mix = quotation_count + pi_count
    won_latest = latest_quotes.count { |quote| quote_display_status(quote) == "won" }
    lost_latest = latest_quotes.count { |quote| quote_display_status(quote) == "lost" }
    decision_ratio = won_latest + lost_latest
    revision_rate = total_groups.zero? ? 0 : ((revised_count.to_f / total_groups) * 100).round(1)
    closed_win_rate = decision_ratio.zero? ? 0 : ((won_latest.to_f / decision_ratio) * 100).round(1)
    follow_up_gap_days = customers.filter_map do |customer|
      next unless customer.last_follow_up_date.present?

      (Date.current - customer.last_follow_up_date).to_i
    end
    avg_follow_up_gap = follow_up_gap_days.empty? ? 0 : (follow_up_gap_days.sum.to_f / follow_up_gap_days.size).round(1)
    cycle_state = quote_cycle_state(closed_cycle_days)
    revision_state = revision_state_for(revision_rate)
    follow_up_state = follow_up_interval_state(avg_follow_up_gap)

    {
      top_product: top_item_name || "Not enough data yet",
      top_product_sample_size: latest_quotes.count,
      average_quote_cycle_days: closed_cycle_days.empty? ? 0 : (closed_cycle_days.sum.to_f / closed_cycle_days.size).round(1),
      closed_cycle_sample_size: closed_cycle_days.size,
      revision_rate: revision_rate,
      export_mix: total_mix.zero? ? "Quotation 0% / PI 0%" : "Quotation #{((quotation_count.to_f / total_mix) * 100).round}% / PI #{((pi_count.to_f / total_mix) * 100).round}%",
      cycle_insight: cycle_state,
      revision_insight: revision_state,
      decision_insight: "Follow-up interval: #{follow_up_state}",
      closed_win_rate: closed_win_rate
    }
  end

  def build_recent_quotes(customers)
    latest_quotes = latest_quotes_from_collection(customers.flat_map(&:quotes))

    latest_quotes
      .sort_by { |quote| [ recent_quote_priority(quote), -(quote.updated_at || Time.zone.at(0)).to_i ] }
      .first(6)
      .map do |quote|
        status = quote_display_status(quote)
        view_signal, next_action = recent_quote_signals(quote, status)

        {
          quote: quote,
          quote_no: quote.quote_no,
          display_name: quote.custom_title.presence || quote.quote_items.ordered.first&.product&.name.presence || quote.quote_items.ordered.first&.description.presence,
          customer_name: quote.customer&.name || "Unknown customer",
          status: status,
          view_signal: view_signal,
          next_action: next_action,
          total: quote.grand_total,
          currency: quote.currency.to_s.upcase.presence || "USD",
          updated_at: quote.updated_at
        }
      end
  end

  def open_deals_count_at(quotes, reference_date)
    revisions_by_quote = quotes.group_by(&:quote_no)

    revisions_by_quote.values.count do |revisions|
      candidate = revisions
        .select { |quote| quote.created_at&.to_date && quote.created_at.to_date <= reference_date }
        .max_by(&:revision_number)
      candidate.present? && %w[draft sent viewed negotiating].include?(quote_display_status_at(candidate, reference_date))
    end
  end

  def quote_display_status_at(quote, reference_date)
    raw_status = quote.status.to_s.downcase
    raw_status = "draft" if raw_status == "pending"
    return "won" if quote.accepted_at.present? && quote.accepted_at.to_date <= reference_date
    if quote.changes_requested_at.present? && quote.changes_requested_at.to_date <= reference_date
      raw_status = "negotiating"
    end
    return "expired" if Quote::OPEN_STATUSES.include?(raw_status) && quote.valid_until.present? && quote.valid_until < reference_date

    raw_status.presence || "draft"
  end

  def summarize_amount_by_currency(cards, status)
    cards
      .select { |card| card[:display_status] == status }
      .group_by { |card| card[:currency].presence || "USD" }
      .transform_values { |currency_cards| currency_cards.sum { |card| card[:current_total].to_d } }
      .sort_by { |currency, _| currency }
      .to_h
  end

  def pending_follow_up_for_reference?(customer, reference_date, period)
    next_date = customer.next_follow_up_date
    return false if next_date.blank?

    window = period == "month" ? 30.days : 7.days
    next_date <= reference_date + window
  end

  def build_kpi_value(current_value, previous_value, period, kind:)
    change = percent_change(current_value, previous_value)
    period_label = period == "month" ? "month" : "week"
    health = kpi_health_state(kind, current_value, change)
    {
      value: current_value,
      trend_text: format("%+d%% vs last %s", change.round, period_label),
      trend_class: kpi_trend_class(kind, change),
      health_label: health[:label],
      health_class: health[:class]
    }
  end

  def percent_change(current_value, previous_value)
    return 0.0 if current_value.to_f.zero? && previous_value.to_f.zero?
    return 100.0 if previous_value.to_f.zero?

    ((current_value.to_f - previous_value.to_f) / previous_value.to_f) * 100
  end

  def kpi_health_state(kind, current_value, change)
    case kind
    when :risk
      if current_value.to_i >= 10 || change >= 30
        { label: "Risk", class: "is-risk" }
      elsif current_value.to_i >= 4 || change >= 10
        { label: "Watch", class: "is-watch" }
      else
        { label: "Stable", class: "is-stable" }
      end
    when :throughput
      if change <= -25
        { label: "Risk", class: "is-risk" }
      elsif change <= -10 || change >= 20
        { label: "Watch", class: "is-watch" }
      else
        { label: "Stable", class: "is-stable" }
      end
    else
      if change <= -20
        { label: "Risk", class: "is-risk" }
      elsif change <= -5 || change >= 15
        { label: "Watch", class: "is-watch" }
      else
        { label: "Stable", class: "is-stable" }
      end
    end
  end

  def kpi_trend_class(kind, change)
    return "is-up" if kind != :risk && change >= 0
    return "is-down" if kind != :risk

    change.positive? ? "is-down" : "is-up"
  end

  def build_risk_snapshot(customers, metrics)
    stalled_high_value = customers.count do |customer|
      high_value_customer?(customer, metrics) && stalled_customer?(customer)
    end
    long_no_follow = customers.count do |customer|
      customer.last_follow_up_date.blank? || customer.last_follow_up_date < Date.current - 14.days
    end

    {
      overdue: customers.count(&:follow_up_overdue?),
      due_today: customers.count(&:follow_up_due_today?),
      stalled_high_value: stalled_high_value,
      no_recent_follow_up: long_no_follow
    }
  end

  def build_action_center(customers, metrics)
    items = []

    customers.select(&:follow_up_due_today?).first(4).each do |customer|
      items << {
        priority: "watch",
        title: "#{customer.name}: follow-up due today",
        detail: "Contact now and update next follow-up date.",
        cta_label: "Open Customer",
        cta_path: customer_path(customer)
      }
    end

    customers.select(&:follow_up_overdue?).first(4).each do |customer|
      overdue_days = (Date.current - customer.next_follow_up_date).to_i
      items << {
        priority: "urgent",
        title: "#{customer.name}: overdue follow-up",
        detail: "Overdue by #{overdue_days} day(s). High risk of inactivity.",
        cta_label: "Open Customer",
        cta_path: customer_path(customer)
      }
    end

    customers.select { |customer| high_value_customer?(customer, metrics) && stalled_customer?(customer) }.first(3).each do |customer|
      items << {
        priority: "urgent",
        title: "#{customer.name}: high value but stalled",
        detail: "Large quote value with no recent movement. Re-engage this account.",
        cta_label: "Open Customer",
        cta_path: customer_path(customer)
      }
    end

    customers.select { |customer| customer.last_follow_up_date.blank? || customer.last_follow_up_date < Date.current - 14.days }.first(3).each do |customer|
      items << {
        priority: "watch",
        title: "#{customer.name}: no recent follow-up",
        detail: "No follow-up in 14+ days. Add this to today's touchpoints.",
        cta_label: "Open Customer",
        cta_path: customer_path(customer)
      }
    end

    customers.select { |customer| customer.next_follow_up_date.blank? }.first(2).each do |customer|
      items << {
        priority: "normal",
        title: "#{customer.name}: no follow-up schedule",
        detail: "Set a next touchpoint to avoid pipeline drop.",
        cta_label: "Open Customer",
        cta_path: customer_path(customer)
      }
    end

    latest_quotes = latest_quotes_from_collection(customers.flat_map(&:quotes))
    stale_cutoff = 7.days.ago
    latest_quotes
      .select { |quote| quote_display_status(quote) == "negotiating" && quote.updated_at.present? && quote.updated_at <= stale_cutoff }
      .first(4)
      .each do |quote|
        stale_days = (Date.current - quote.updated_at.to_date).to_i
        items << {
          priority: "urgent",
          title: "Quote #{quote.quote_no}: negotiating stalled",
          detail: "No update for #{stale_days} day(s). Push next revision or close decision.",
          cta_label: "Open Quote",
          cta_path: quote_path(quote)
        }
      end

    order = { "urgent" => 0, "watch" => 1, "normal" => 2 }
    items.uniq { |item| item[:title] }.sort_by { |item| [ order.fetch(item[:priority], 9), item[:title] ] }.first(9)
  end

  def build_decision_snapshot(customers, period)
    latest_quotes = latest_quotes_from_collection(customers.flat_map(&:quotes))
    period_start = period == "month" ? Date.current.beginning_of_month : Date.current.beginning_of_week

    accepted_count = latest_quotes.count do |quote|
      quote.accepted_at.present? && quote.accepted_at.to_date >= period_start
    end

    revision_requested_count = latest_quotes.count do |quote|
      quote.changes_requested_at.present? && quote.changes_requested_at.to_date >= period_start
    end

    reopened_count = latest_quotes.count do |quote|
      quote.reopened_at.present? && quote.reopened_at.to_date >= period_start
    end

    negotiating_stale_count = latest_quotes.count do |quote|
      quote_display_status(quote) == "negotiating" && quote.updated_at.present? && quote.updated_at <= 7.days.ago
    end

    public_actionable_count = latest_quotes.count do |quote|
      %w[sent viewed negotiating].include?(quote_display_status(quote)) &&
        quote.accepted_at.blank? &&
        quote.changes_requested_at.blank?
    end

    reason_counts = Hash.new(0)
    latest_quotes.each do |quote|
      message = quote.changes_request_message.to_s
      next if message.blank?

      match = message.match(/Reasons:\s*([^|]+)/i)
      if match
        match[1].split(";").map(&:strip).reject(&:blank?).each { |reason| reason_counts[reason] += 1 }
      elsif quote.changes_requested_at.present?
        reason_counts["Custom request"] += 1
      end
    end

    {
      accepted_count: accepted_count,
      revision_requested_count: revision_requested_count,
      reopened_count: reopened_count,
      negotiating_stale_count: negotiating_stale_count,
      public_actionable_count: public_actionable_count,
      top_revision_reasons: reason_counts.sort_by { |(_, count)| -count }.first(2)
    }
  end

  def high_value_customer?(customer, metrics)
    total = metrics.fetch(customer)[:total_quote_amount].to_d
    threshold = metrics.values.map { |data| data[:total_quote_amount].to_d }.sort.last((metrics.size * 0.2).ceil.nonzero? || 1).min.to_d
    total >= threshold && total.positive?
  end

  def stalled_customer?(customer)
    latest_quote = customer.quotes.max_by(&:updated_at)
    latest_quote.present? && latest_quote.updated_at.to_date <= Date.current - 14.days
  end

  def quote_cycle_state(closed_cycle_days)
    return "Within healthy band" if closed_cycle_days.empty?

    average_days = closed_cycle_days.sum.to_f / closed_cycle_days.size
    return "Within healthy band" if average_days <= 14
    return "Below target" if average_days <= 28

    "Above optimal range"
  end

  def revision_state_for(revision_rate)
    return "Within healthy band" if revision_rate <= 25
    return "Below target" if revision_rate <= 45

    "Above optimal range"
  end

  def follow_up_interval_state(avg_follow_up_gap)
    return "Within healthy band" if avg_follow_up_gap <= 7
    return "Below target" if avg_follow_up_gap <= 14

    "Above optimal range"
  end

  def recent_quote_priority(quote)
    status = quote_display_status(quote)
    return 5 if status == "lost" || status == "won"
    return 0 if status == "sent" && quote.viewed_at.blank? && quote.sent_at.present? && quote.sent_at <= 3.days.ago
    return 1 if status == "sent" && quote.viewed_at.blank?
    return 2 if status == "draft"
    return 1 if status == "expired"
    return 3 if status == "negotiating"
    return 4 if status == "viewed"

    6
  end

  def recent_quote_next_action(quote, status)
    if status == "sent" && quote.viewed_at.blank?
      "Send reminder"
    elsif status == "expired"
      "Create revision"
    elsif status == "negotiating"
      "Push to close"
    elsif status == "viewed"
      "Follow up now"
    else
      "Review"
    end
  end

  def recent_quote_signals(quote, status)
    if status == "draft"
      [
        "Draft unsent",
        { label: "Send Now", path: edit_quote_path(quote), style: "is-watch" }
      ]
    elsif status == "sent" && quote.viewed_at.blank? && quote.sent_at.present? && quote.sent_at <= 3.days.ago
      [
        "Sent, no view 3d+",
        { label: "Send Reminder", path: quote_path(quote), style: "is-attention" }
      ]
    elsif status == "sent" && quote.viewed_at.blank?
      [
        "Sent, awaiting view",
        { label: "Check Signal", path: quote_path(quote), style: "is-watch" }
      ]
    elsif %w[viewed negotiating].include?(status)
      [
        "Viewed",
        { label: "Follow Up Today", path: quote_path(quote), style: "is-primary" }
      ]
    else
      [
        "No active signal",
        { label: recent_quote_next_action(quote, status), path: quote_path(quote), style: "is-neutral" }
      ]
    end
  end

  def quote_push_signal(quote, status, customer)
    if status == "draft"
      {
        priority: 0,
        state: "watch",
        summary: "Draft not sent",
        detail: "Complete and send this quote.",
        label: "Complete & Send",
        path: edit_quote_path(quote),
        method: :get
      }
    elsif status == "sent" && quote.viewed_at.blank?
      sent_days = quote.sent_at.present? ? (Date.current - quote.sent_at.to_date).to_i : 0
      if sent_days >= 7
        {
          priority: 0,
          state: "risk",
          summary: "Sent 7d+ with no view",
          detail: "Send a reminder or share again.",
          label: "Send Reminder",
          path: quote_path(quote),
          method: :get
        }
      else
        {
          priority: 2,
          state: "watch",
          summary: "Sent, awaiting first view",
          detail: "Monitor customer signal.",
          label: "Check Status",
          path: quote_path(quote),
          method: :get
        }
      end
    elsif %w[viewed negotiating].include?(status) && viewed_without_follow_up?(quote, customer)
      {
        priority: 1,
        state: "watch",
        summary: "Viewed, no follow-up",
        detail: "Schedule next touchpoint now.",
        label: "Schedule Follow-up",
        path: schedule_follow_up_customer_path(customer, days: 3),
        method: :post
      }
    elsif status == "expired"
      {
        priority: 1,
        state: "risk",
        summary: "Expired quote",
        detail: "Create revision to re-open conversation.",
        label: "Create Revision",
        path: duplicate_quote_path(quote),
        method: :post
      }
    else
      {
        priority: 4,
        state: "stable",
        summary: "No immediate action",
        detail: "Review quote details when needed.",
        label: "Review",
        path: quote_path(quote),
        method: :get
      }
    end
  end

  def viewed_without_follow_up?(quote, customer)
    return false if quote.viewed_at.blank?

    customer.last_follow_up_date.blank? || customer.last_follow_up_date < quote.viewed_at.to_date
  end

  def filter_quote_cards_by_query(cards, query)
    return cards if query.blank?

    normalized = query.downcase
    cards.select do |card|
      quote = card[:quote]
      searchable_text = [
        card[:quote_no],
        card[:title],
        quote.notes,
        quote.quote_items.map { |item| item.description.to_s }.join(" ")
      ].compact.join(" ").downcase

      searchable_text.include?(normalized)
    end
  end

  def sort_quote_cards(cards, sort_key)
    status_order = {
      "draft" => 0,
      "sent" => 1,
      "viewed" => 2,
      "negotiating" => 3,
      "expired" => 4,
      "won" => 5,
      "lost" => 6
    }

    case sort_key
    when "newest"
      cards.sort_by { |card| -(card[:updated_at] || Time.zone.at(0)).to_i }
    when "amount_high"
      cards.sort_by { |card| -card[:current_total].to_d }
    when "status"
      cards.sort_by { |card| [ status_order.fetch(card[:display_status], 9), -(card[:updated_at] || Time.zone.at(0)).to_i ] }
    else
      cards.sort_by do |card|
        signal = card[:push_signal] || quote_push_signal(card[:quote], card[:display_status], card[:quote].customer)
        [ signal[:priority], -(card[:updated_at] || Time.zone.at(0)).to_i ]
      end
    end
  end

  def actionable_quote_card?(card, customer)
    status = card[:display_status]
    quote = card[:quote]
    return true if status == "draft"
    return true if status == "sent" && quote.viewed_at.blank?
    return true if status == "negotiating"
    return true if status == "viewed" && viewed_without_follow_up?(quote, customer)

    false
  end

  def paginate_cards(cards, page_param, per_page:)
    page = page_param.to_i
    page = 1 if page < 1
    total_pages = (cards.size.to_f / per_page).ceil
    total_pages = 1 if total_pages.zero?
    page = [ page, total_pages ].min
    offset = (page - 1) * per_page

    {
      page: page,
      total_pages: total_pages,
      items: cards.slice(offset, per_page) || []
    }
  end

  def customer_engagement_state(customer, latest_signal_at)
    if customer.follow_up_overdue?
      { label: "At Risk", css: "is-risk" }
    elsif latest_signal_at.present? && latest_signal_at.to_date >= Date.current - 7.days
      { label: "Active", css: "is-active" }
    elsif latest_signal_at.present? && latest_signal_at.to_date >= Date.current - 21.days
      { label: "Cooling", css: "is-cooling" }
    else
      { label: "At Risk", css: "is-risk" }
    end
  end

  def follow_up_text_for(customer)
    if customer.follow_up_overdue?
      "Follow-up overdue. Action required now."
    elsif customer.follow_up_due_today?
      "Follow-up due today."
    elsif customer.follow_up_status == "upcoming"
      "Follow-up scheduled soon."
    else
      "No follow-up date scheduled."
    end
  end

  def follow_up_primary_action_for(customer)
    if customer.follow_up_overdue? || customer.follow_up_due_today?
      { label: "Mark Followed Today", path: mark_follow_up_customer_path(customer), method: :post }
    elsif customer.next_follow_up_date.blank?
      { label: "Schedule +7d", path: schedule_follow_up_customer_path(customer, days: 7), method: :post }
    else
      { label: "Adjust Follow-up", path: edit_customer_path(customer), method: :get }
    end
  end

  def build_customer_row_signals(customers, metrics)
    customers.each_with_object({}) do |customer, hash|
      metrics_data = metrics.fetch(customer)
      signal =
        if customer.follow_up_overdue?
          { label: "Follow today", klass: "is-danger", row_risk: "risk-high", reason: "Overdue follow-up" }
        elsif customer.follow_up_due_today?
          { label: "Contact now", klass: "is-today", row_risk: "risk-medium", reason: "Due today" }
        elsif high_value_customer?(customer, metrics) && stalled_customer?(customer)
          { label: "Re-engage", klass: "is-upcoming", row_risk: "risk-medium", reason: "High value but stalled" }
        elsif customer.follow_up_upcoming?
          { label: "Prepare quote", klass: "is-upcoming", row_risk: "risk-low", reason: "Due soon" }
        else
          { label: "Set schedule", klass: "is-muted", row_risk: "risk-low", reason: "No urgent risk" }
        end

      hash[customer.id] = signal.merge(total_quote_amount: metrics_data[:total_quote_amount].to_d)
    end
  end

  def customer_risk_rank(customer)
    return 0 if customer.follow_up_overdue?
    return 1 if customer.follow_up_due_today?
    return 2 if customer.follow_up_upcoming?
    return 3 if customer.next_follow_up_date.blank?

    4
  end

  def build_follow_up_tasks(customer, quote_cards)
    tasks = []
    today = Date.current

    if customer.next_follow_up_date.blank?
      tasks << {
        priority: "normal",
        title: "Set next follow-up date",
        detail: "No follow-up date is scheduled for this customer.",
        cta_label: nil,
        cta_path: nil
      }
    elsif customer.follow_up_overdue?
      overdue_days = (today - customer.next_follow_up_date).to_i
      tasks << {
        priority: "urgent",
        title: "Follow-up overdue",
        detail: "Overdue by #{overdue_days} day(s). Contact customer now.",
        cta_label: nil,
        cta_path: nil
      }
    elsif customer.follow_up_due_today?
      tasks << {
        priority: "today",
        title: "Follow-up due today",
        detail: "Touch base with customer and update next action.",
        cta_label: nil,
        cta_path: nil
      }
    else
      days_left = (customer.next_follow_up_date - today).to_i
      tasks << {
        priority: days_left <= 7 ? "upcoming" : "normal",
        title: "Upcoming follow-up",
        detail: "Scheduled in #{days_left} day(s) on #{customer.next_follow_up_date.strftime('%Y-%m-%d')}.",
        cta_label: nil,
        cta_path: nil
      }
    end

    quote_cards.each do |card|
      quote = card[:quote]
      status = card[:display_status]
      next unless %w[sent viewed negotiating draft].include?(status)

      if quote.valid_until.present?
        days_left = (quote.valid_until - today).to_i
        if days_left.negative?
          tasks << {
            priority: "urgent",
            title: "Quote #{quote.quote_no} expired",
            detail: "Expired on #{quote.valid_until.strftime('%Y-%m-%d')}. Consider sending a revision.",
            cta_label: "Open Quote",
            cta_path: quote_path(quote)
          }
          next
        elsif days_left <= 3
          tasks << {
            priority: "today",
            title: "Quote #{quote.quote_no} expiring soon",
            detail: "Expires in #{days_left} day(s). Follow up before expiry.",
            cta_label: "Open Quote",
            cta_path: quote_path(quote)
          }
        end
      end

      if quote.sent_at.present? && quote.viewed_at.blank?
        tasks << {
          priority: "upcoming",
          title: "Quote #{quote.quote_no} not viewed yet",
          detail: "Sent at #{quote.sent_at.strftime('%Y-%m-%d %H:%M')}. Consider a reminder.",
          cta_label: "Open Quote",
          cta_path: quote_path(quote)
        }
      end
    end

    priority_order = { "urgent" => 0, "today" => 1, "upcoming" => 2, "normal" => 3 }
    tasks.sort_by { |task| [ priority_order.fetch(task[:priority], 4), task[:title] ] }.first(8)
  end

  def build_customer_timeline(customer, quote_cards)
    events = []

    events << {
      at: customer.created_at,
      tone: "normal",
      category: "system_activity",
      title: "Customer created",
      detail: "#{customer.name} was added to your workspace."
    }

    if customer.last_follow_up_date.present?
      events << {
        at: customer.last_follow_up_date.in_time_zone.end_of_day,
        tone: "good",
        category: "high_signal",
        title: "Follow-up completed",
        detail: "Last follow-up marked on #{customer.last_follow_up_date.strftime('%Y-%m-%d')}."
      }
    end

    if customer.next_follow_up_date.present?
      tone = customer.follow_up_overdue? ? "urgent" : (customer.follow_up_due_today? ? "today" : "normal")
      events << {
        at: customer.next_follow_up_date.in_time_zone.beginning_of_day,
        tone: tone,
        category: "system_activity",
        title: "Next follow-up scheduled",
        detail: customer.next_follow_up_date.strftime("%Y-%m-%d")
      }
    end

    quote_cards.each do |card|
      quote = card[:quote]
      events << {
        at: quote.created_at,
        tone: "normal",
        category: "system_activity",
        title: "Quote #{quote.quote_no} created",
        detail: "Revision V#{quote.revision_number}."
      }

      if quote.updated_at.present? && quote.updated_at > quote.created_at
        events << {
          at: quote.updated_at,
          tone: "normal",
          category: "system_activity",
          title: "Quote #{quote.quote_no} updated",
          detail: "Latest status: #{card[:display_status].capitalize}."
        }
      end

      if quote.sent_at.present?
        events << {
          at: quote.sent_at,
          tone: "today",
          category: "system_activity",
          title: "Quote #{quote.quote_no} sent",
          detail: "Sent to customer."
        }
      end

      if quote.viewed_at.present?
        events << {
          at: quote.viewed_at,
          tone: "good",
          category: "high_signal",
          title: "Quote #{quote.quote_no} viewed",
          detail: "Customer opened the quote."
        }
      end

      if quote.changes_requested_at.present?
        events << {
          at: quote.changes_requested_at,
          tone: "today",
          category: "high_signal",
          title: "Quote #{quote.quote_no} revision requested",
          detail: quote.changes_request_message.present? ? "Client request: #{quote.changes_request_message}" : "Customer requested updates to this revision."
        }
      end

      if quote.accepted_at.present?
        events << {
          at: quote.accepted_at,
          tone: "good",
          category: "high_signal",
          title: "Quote #{quote.quote_no} accepted",
          detail: "Customer accepted this quotation revision via public link."
        }
      end

      if quote.reopened_at.present?
        events << {
          at: quote.reopened_at,
          tone: "normal",
          category: "system_activity",
          title: "Quote #{quote.quote_no} reopened",
          detail: "Reopened internally to continue commercial discussion."
        }
      end

      if card[:display_status] == "won" && quote.accepted_at.blank?
        events << {
          at: quote.updated_at,
          tone: "good",
          category: "high_signal",
          title: "Quote #{quote.quote_no} won",
          detail: "Quotation marked as Won internally."
        }
      end

      if %w[lost expired].include?(card[:display_status])
        tone = card[:display_status] == "lost" ? "urgent" : "normal"
        status_detail =
          if card[:display_status] == "lost" && quote.loss_reason.present?
            "Marked Lost. Reason: #{quote.loss_reason}"
          else
            "Final status changed to #{card[:display_status].capitalize}."
          end
        events << {
          at: quote.updated_at,
          tone: tone,
          category: card[:display_status] == "lost" ? "high_signal" : "system_activity",
          title: "Quote #{quote.quote_no} #{card[:display_status]}",
          detail: status_detail
        }
      end

      shares = quote.quote_shares.to_a
      if shares.any?
        latest_share = shares.max_by(&:created_at)
        events << {
          at: latest_share.created_at,
          tone: "normal",
          category: "system_activity",
          title: shares.size > 1 ? "Public links shared (#{shares.size})" : "Public link shared",
          detail: "Quote #{quote.quote_no} public link generated."
        }

        first_view = shares.filter_map(&:first_viewed_at).min
        if first_view.present?
          events << {
            at: first_view,
            tone: "good",
            category: "high_signal",
            title: "Public link first viewed",
            detail: "Quote #{quote.quote_no} viewed via public link."
          }
        end

        latest_view = shares.filter_map(&:last_viewed_at).max
        total_views = shares.sum { |share| share.view_count.to_i }
        if latest_view.present? && total_views.positive?
          events << {
            at: latest_view,
            tone: "normal",
            category: "system_activity",
            title: "Public link activity",
            detail: "Quote #{quote.quote_no} viewed #{total_views} time#{'s' unless total_views == 1}."
          }
        end
      end
    end

    deduped = events.uniq { |event| [ event[:title], event[:detail], event[:at]&.to_i ] }
    deduped.sort_by { |event| event[:at] || Time.zone.at(0) }.reverse
  end
end
