class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    scope = current_user.company.customers.search(params[:query]).includes(quotes: [ :quote_items, :template ])
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
    @deal_overview = build_deal_overview(all_customers)
    @recent_quotes = build_recent_quotes(all_customers)
  end

  def show
    quote_groups = @customer.quotes.includes(:quote_items).order(:quote_no, :revision_number).group_by(&:quote_no)
    @quote_cards = quote_groups.values.map { |revisions| build_quote_card(revisions) }
    @quote_cards.sort_by! { |card| card[:updated_at] || Time.at(0) }.reverse!

    @quote_status_filter = params[:quote_status].presence_in(%w[all won lost pending expired]) || "all"
    @filtered_quote_cards =
      if @quote_status_filter == "all"
        @quote_cards
      else
        @quote_cards.select { |card| card[:display_status] == @quote_status_filter }
      end

    @quote_summary = {
      total_count: @quote_cards.count,
      won_count: @quote_cards.count { |card| card[:display_status] == "won" },
      lost_count: @quote_cards.count { |card| card[:display_status] == "lost" },
      pending_count: @quote_cards.count { |card| card[:display_status] == "pending" },
      expired_count: @quote_cards.count { |card| card[:display_status] == "expired" },
      won_amount: @quote_cards.select { |card| card[:display_status] == "won" }.sum { |card| card[:current_total].to_d },
      lost_amount: @quote_cards.select { |card| card[:display_status] == "lost" }.sum { |card| card[:current_total].to_d },
      avg_discount_pct: average_discount_percentage(@quote_cards)
    }
  end

  def new
    @customer = current_user.company.customers.new
  end

  def create
    unless current_user.can_create_customer?
      redirect_to customers_path, alert: "Free plan limit reached: #{current_user.customer_count_for_limit}/#{User::FREE_CUSTOMER_LIMIT} customers used." and return
    end

    @customer = current_user.company.customers.new(customer_params)

    if @customer.save
      redirect_to @customer
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer
    else
      render :edit
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path
  end

  def mark_follow_up
    @customer = current_user.company.customers.find(params[:id])
    @customer.mark_followed_today!
    redirect_to @customer, notice: "Follow-up marked for today. Next follow-up scheduled at #{@customer.next_follow_up_date.strftime('%Y-%m-%d')}"
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :country,
      :address,
      :contact_name,
      :email,
      :phone,
      :status,
      :next_follow_up_date,
      :last_follow_up_date,
      :notes
    )
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
      original_total: original_total,
      diff_amount: diff_amount,
      diff_pct: diff_pct,
      changed_from_original: ordered.size > 1 && diff_amount.nonzero?,
      trend: trend,
      updated_at: latest.updated_at
    }
  end

  def quote_display_status(quote)
    return "expired" if quote.status == "pending" && quote.valid_until.present? && quote.valid_until < Date.current

    quote.status.presence || "pending"
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
      customers.sort_by { |customer| customer.next_follow_up_date || Date.new(9999, 12, 31) }
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
      open_deals: build_kpi_value(open_deals_now, open_deals_previous, period),
      quotes_this_week: build_kpi_value(this_period_count, last_period_count, period),
      pending_follow_ups: build_kpi_value(pending_follow_ups_now, pending_follow_ups_previous, period)
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

    {
      top_product: top_item_name || "Not enough data yet",
      average_quote_cycle_days: closed_cycle_days.empty? ? 0 : (closed_cycle_days.sum.to_f / closed_cycle_days.size).round(1),
      revision_rate: total_groups.zero? ? 0 : ((revised_count.to_f / total_groups) * 100).round(1),
      export_mix: total_mix.zero? ? "Quotation 0% / PI 0%" : "Quotation #{((quotation_count.to_f / total_mix) * 100).round}% / PI #{((pi_count.to_f / total_mix) * 100).round}%"
    }
  end

  def build_recent_quotes(customers)
    latest_quotes = latest_quotes_from_collection(customers.flat_map(&:quotes))

    latest_quotes
      .sort_by { |quote| quote.updated_at || Time.zone.at(0) }
      .reverse
      .first(6)
      .map do |quote|
        {
          quote: quote,
          quote_no: quote.quote_no,
          customer_name: quote.customer&.name || "Unknown customer",
          status: quote_display_status(quote),
          total: quote.grand_total,
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
      candidate.present? && quote_display_status_at(candidate, reference_date) == "pending"
    end
  end

  def quote_display_status_at(quote, reference_date)
    return "expired" if quote.status == "pending" && quote.valid_until.present? && quote.valid_until < reference_date

    quote.status.presence || "pending"
  end

  def pending_follow_up_for_reference?(customer, reference_date, period)
    next_date = customer.next_follow_up_date
    return false if next_date.blank?

    window = period == "month" ? 30.days : 7.days
    next_date <= reference_date + window
  end

  def build_kpi_value(current_value, previous_value, period)
    change = percent_change(current_value, previous_value)
    period_label = period == "month" ? "month" : "week"
    {
      value: current_value,
      trend_text: format("%+d%% vs last %s", change.round, period_label),
      trend_class: change.negative? ? "is-down" : "is-up"
    }
  end

  def percent_change(current_value, previous_value)
    return 0.0 if current_value.to_f.zero? && previous_value.to_f.zero?
    return 100.0 if previous_value.to_f.zero?

    ((current_value.to_f - previous_value.to_f) / previous_value.to_f) * 100
  end
end
