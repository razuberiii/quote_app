class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy mark_follow_up schedule_follow_up log_follow_up send_follow_up_email send_follow_up_whatsapp]
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
    @dashboard_health_snapshot = build_dashboard_health_snapshot(all_customers)
    @recent_quotes = build_recent_quotes(all_customers)
    @customer_row_signals = build_customer_row_signals(@customers, @customer_metrics)
  end

  def show
    Quote.expire_overdue_for_company!(current_user.company_id)
    all_customer_quotes = @customer.quotes.includes(:quote_items, :quote_shares).order(:quote_no, :revision_number).to_a
    customer_quotes = active_quotes_collection(all_customer_quotes)
    quote_groups = customer_quotes.group_by(&:quote_no)
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
    assistant = FollowUpAssistantService.new(
      customer: @customer,
      url_options: follow_up_url_options
    )
    @follow_up_assistant_quote = assistant.relevant_quote
    @follow_up_quote_signal = quote_signal_for(@follow_up_assistant_quote)
    @follow_up_quote_view_status = follow_up_quote_view_status(@follow_up_assistant_quote)
    @follow_up_quote_expiry_status = follow_up_quote_expiry_status(@follow_up_assistant_quote)
    @suggested_follow_up_message = FollowUpAssistantService.new(
      customer: @customer,
      latest_quote: @follow_up_assistant_quote,
      quote_view_status: @follow_up_quote_view_status,
      quote_expiry_status: @follow_up_quote_expiry_status,
      quote_signal: @follow_up_quote_signal,
      url_options: follow_up_url_options
    ).call
    @customer_follow_up_events = @customer.customer_follow_up_events.includes(:user, :quote).recent_first.to_a
    @customer_summary = {
      total_quotes: @quote_cards.count,
      latest_quote_at: latest_quote&.dig(:updated_at),
      sales_stage: @customer.status_label,
      last_follow_up_at: @customer.last_follow_up_date
    }
    @best_contact_time = CustomerEngagementAnalyticsService.new(@customer).best_contact_time
    @follow_up_tasks = build_follow_up_tasks(@customer, @quote_cards)
    @visible_follow_up_tasks = @follow_up_tasks.first(2)
    @hidden_follow_up_tasks = @follow_up_tasks.drop(2)
    @timeline_events = build_customer_timeline(@customer, @quote_cards, all_customer_quotes, @customer_follow_up_events)
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
    @customer_operating_signals = build_customer_operating_signals(@customer, @quote_cards, @latest_customer_signal_at)
  end

  def new
    @customer = current_user.company.customers.new
    @customer.internal_owner ||= current_user if Customer.internal_owner_enabled?
  end

  def create
    unless current_user.can_create_customer?
      redirect_to customers_path, alert: t("customers.flash.free_plan_limit_reached", used: current_user.customer_count_for_limit, limit: User::FREE_CUSTOMER_LIMIT) and return
    end

    @customer = current_user.company.customers.new
    @customer.assign_attributes(customer_params.except(:customer_tag_ids, :tag_priority_names))
    @customer.internal_owner ||= current_user if Customer.internal_owner_enabled?
    resolved_tag_ids = resolve_customer_tag_ids

    if @customer.save
      sync_customer_tags(@customer, resolved_tag_ids)
      redirect_to @customer
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @customer.assign_attributes(customer_params.except(:customer_tag_ids, :tag_priority_names))
    resolved_tag_ids = resolve_customer_tag_ids

    if @customer.save
      sync_customer_tags(@customer, resolved_tag_ids)
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
    @customer.mark_followed_today!(
      user: current_user,
      channel: "manual",
      quote: requested_follow_up_quote,
      note: nil,
      metadata: follow_up_metadata(source: "mark_follow_up")
    )
    redirect_to @customer, notice: t("customers.flash.follow_up_marked_today", date: @customer.next_follow_up_date.strftime("%Y-%m-%d"))
  end

  def schedule_follow_up
    days = params[:days].to_i
    allowed_days = [ 0, 3, 7, 14, 30 ]
    unless allowed_days.include?(days)
      redirect_to @customer, alert: t("customers.flash.unsupported_follow_up_interval") and return
    end

    target_date = Date.current + days.days
    if @customer.update(next_follow_up_date: target_date)
      label = days.zero? ? "today" : "in #{days} days"
      redirect_to @customer, notice: t("customers.flash.next_follow_up_scheduled", date: target_date.strftime("%Y-%m-%d"), label: label)
    else
      redirect_to @customer, alert: @customer.errors.full_messages.to_sentence
    end
  end

  def log_follow_up
    @customer.mark_followed_today!(
      user: current_user,
      channel: "manual",
      quote: requested_follow_up_quote || latest_follow_up_quote,
      note: follow_up_message.presence,
      metadata: follow_up_metadata(source: "assistant_log")
    )

    redirect_to @customer, notice: t("follow_up.flash.logged", date: @customer.next_follow_up_date.strftime("%Y-%m-%d"))
  end

  def send_follow_up_email
    unless verify_turnstile_for_html!(
      token: params[:cf_turnstile_response],
      on_missing: -> { redirect_to @customer, alert: t("follow_up.flash.email_verification_required") },
      on_failed: -> { redirect_to @customer, alert: t("follow_up.flash.email_verification_failed") }
    )
      return
    end

    quote = requested_follow_up_quote || latest_follow_up_quote
    message = follow_up_message(quote)

    if @customer.email.blank?
      redirect_to @customer, alert: t("follow_up.flash.email_missing") and return
    end

    FollowUpMailer.with(customer: @customer, message: message, sender: current_user, quote: quote).follow_up_email.deliver_now
    @customer.mark_followed_today!(
      user: current_user,
      channel: "email",
      quote: quote,
      note: message,
      metadata: follow_up_metadata(source: "assistant_email", quote: quote)
    )

    redirect_to @customer, notice: t("follow_up.flash.email_sent", date: @customer.next_follow_up_date.strftime("%Y-%m-%d"))
  rescue StandardError => e
    Rails.logger.error("Follow-up email failed: #{e.class} #{e.message}")
    redirect_to @customer, alert: t("follow_up.flash.email_failed")
  end

  def send_follow_up_whatsapp
    quote = requested_follow_up_quote || latest_follow_up_quote
    message = follow_up_message(quote)
    url = helpers.whatsapp_follow_up_link(@customer, message)

    if url.blank?
      respond_to do |format|
        format.json { render json: { message: t("follow_up.flash.whatsapp_unavailable") }, status: :unprocessable_entity }
        format.html { redirect_to @customer, alert: t("follow_up.flash.whatsapp_unavailable") }
      end
      return
    end

    @customer.mark_followed_today!(
      user: current_user,
      channel: "whatsapp",
      quote: quote,
      note: message,
      metadata: follow_up_metadata(source: "assistant_whatsapp", quote: quote)
    )

    respond_to do |format|
      format.json do
        render json: {
          url: url,
          redirect_url: customer_path(@customer),
          notice: t("follow_up.flash.whatsapp_logged", date: @customer.next_follow_up_date.strftime("%Y-%m-%d"))
        }
      end
      format.html { redirect_to url, allow_other_host: true }
    end
  rescue StandardError => e
    Rails.logger.error("Follow-up WhatsApp failed: #{e.class} #{e.message}")
    respond_to do |format|
      format.json { render json: { message: t("follow_up.flash.whatsapp_failed") }, status: :internal_server_error }
      format.html { redirect_to @customer, alert: t("follow_up.flash.whatsapp_failed") }
    end
  end

  private

  def follow_up_params
    params.fetch(:follow_up, {}).permit(:message, :quote_id)
  end

  def requested_follow_up_quote
    return @requested_follow_up_quote if defined?(@requested_follow_up_quote)

    quote_id = follow_up_params[:quote_id].presence
    @requested_follow_up_quote = quote_id.present? ? @customer.quotes.not_archived.find_by(id: quote_id) : nil
  end

  def latest_follow_up_quote
    return @latest_follow_up_quote if defined?(@latest_follow_up_quote)

    quotes = @customer.quotes.includes(:quote_items, :quote_shares).order(:quote_no, :revision_number).to_a
    @latest_follow_up_quote = active_quotes_collection(quotes).max_by { |quote| quote.updated_at || Time.at(0) }
  end

  def follow_up_message(quote = nil)
    explicit_message = follow_up_params[:message].to_s.strip
    return explicit_message if explicit_message.present?

    quote ||= requested_follow_up_quote || latest_follow_up_quote
    signal = quote_signal_for(quote)
    FollowUpAssistantService.new(
      customer: @customer,
      latest_quote: quote,
      quote_view_status: follow_up_quote_view_status(quote),
      quote_expiry_status: follow_up_quote_expiry_status(quote),
      quote_signal: signal,
      url_options: follow_up_url_options
    ).call
  end

  def follow_up_metadata(source:, quote: nil)
    quote ||= requested_follow_up_quote || latest_follow_up_quote

    {
      source: source,
      quote_no: quote&.quote_no,
      quote_view_status: follow_up_quote_view_status(quote),
      quote_expiry_status: follow_up_quote_expiry_status(quote),
      quote_signal: quote_signal_for(quote)&.type
    }.compact
  end

  def quote_signal_for(quote)
    return nil if quote.blank?

    @quote_signal_map ||= {}
    @quote_signal_map[quote.id] ||= QuoteSignalService.new(quote).call
  end

  def follow_up_quote_view_status(quote)
    return "unknown" if quote.blank?
    return "viewed" if quote.viewed_at.present? || quote.workflow_state == "viewed"
    return "not_viewed" if quote.sent_at.present? && quote.viewed_at.blank?

    "generic"
  end

  def follow_up_quote_expiry_status(quote)
    return "active" if quote.blank?
    return "expired" if quote.workflow_state == "expired" || quote.expired_by_date?

    "active"
  end

  def follow_up_url_options
    {
      host: request.host,
      protocol: request.protocol.delete_suffix("://"),
      port: request.optional_port
    }
  end

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
      :phone_country_code,
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
      :avatar,
      :tax_id,
      :tax_id_type
    ]
    permitted_keys << :internal_owner_id if Customer.internal_owner_enabled?
    permitted = params.require(:customer).permit(*permitted_keys, customer_tag_ids: [], tag_priority_names: [])
    permitted[:customer_tag_ids] = Array(permitted[:customer_tag_ids]).reject(&:blank?)
    permitted[:tag_priority_names] = Array(permitted[:tag_priority_names]).reject(&:blank?)
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

  def resolve_customer_tag_ids
    selected_tag_ids = Array(params.dig(:customer, :customer_tag_ids)).reject(&:blank?).map(&:to_i)
    ordered_names = Array(params.dig(:customer, :tag_priority_names)).map { |name| normalize_tag_name(name) }.reject(&:blank?)
    custom_names = Array(params.dig(:customer, :new_tag_names)).map { |name| name.to_s.split(",") }.flatten
    custom_names.concat(customer_custom_tags_input.to_s.split(","))
    ordered_names.concat(custom_names.map { |name| normalize_tag_name(name) })
    ordered_names.uniq!

    selected_tags = current_user.company.customer_tags.where(id: selected_tag_ids).to_a
    selected_tags.each do |tag|
      ordered_names << tag.name unless ordered_names.include?(tag.name)
    end

    return [] if ordered_names.empty?

    ordered_names.map do |name|
      current_user.company.customer_tags.find_or_create_by!(name: name).id
    end
  end

  def sync_customer_tags(customer, ordered_tag_ids)
    customer.customer_taggings.where.not(customer_tag_id: ordered_tag_ids).delete_all

    ordered_tag_ids.each_with_index do |tag_id, index|
      tagging = customer.customer_taggings.find_or_initialize_by(customer_tag_id: tag_id)
      tagging.position = index + 1
      tagging.save! if tagging.new_record? || tagging.changed?
    end
  end

  def customer_custom_tags_input
    params.dig(:customer, :custom_tags_input)
  end

  def normalize_tag_name(name)
    name.to_s.strip.gsub(/\s+/, " ")
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
      quotes = latest_quotes_from_collection(active_quotes_collection(customer.quotes))
      total_quote_amount = quotes.sum { |quote| quote.grand_total.to_d }
      won_quotes = quotes.select { |quote| quote_display_status(quote) == "won" }
      total_won_amount = won_quotes.sum { |quote| quote.display_amount.to_d }
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

  def active_quotes_collection(quotes)
    Array(quotes).reject do |quote|
      (quote.respond_to?(:archived?) && quote.archived?) ||
        (quote.respond_to?(:deleted?) && quote.deleted?)
    end
  end

  def active_quotes_from_customers(customers)
    customers.flat_map { |customer| active_quotes_collection(customer.quotes) }
  end

  def build_dashboard_stats(customers, follow_up_counts, period)
    all_quotes = active_quotes_from_customers(customers)
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
    all_quotes = active_quotes_from_customers(customers)
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
      top_product: top_item_name || I18n.t("dashboard.logic.not_enough_data"),
      top_product_sample_size: latest_quotes.count,
      average_quote_cycle_days: closed_cycle_days.empty? ? 0 : (closed_cycle_days.sum.to_f / closed_cycle_days.size).round(1),
      closed_cycle_sample_size: closed_cycle_days.size,
      revision_rate: revision_rate,
      export_mix: total_mix.zero? ? I18n.t("dashboard.logic.export_mix_zero") : I18n.t("dashboard.logic.export_mix", quotation: ((quotation_count.to_f / total_mix) * 100).round, pi: ((pi_count.to_f / total_mix) * 100).round),
      cycle_insight: cycle_state,
      revision_insight: revision_state,
      decision_insight: I18n.t("dashboard.logic.follow_up_interval", state: follow_up_state),
      closed_win_rate: closed_win_rate
    }
  end

  def build_dashboard_health_snapshot(customers)
    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(customers))
    active_quotes = latest_quotes.select { |quote| %w[draft sent viewed negotiating expired].include?(quote_display_status(quote)) }
    viewed_quotes = active_quotes.select do |quote|
      quote.viewed_at.present? || quote.quote_shares.sum(&:view_count).positive?
    end
    recent_motion_quotes = active_quotes.select do |quote|
      [
        quote.updated_at,
        quote.sent_at,
        quote.viewed_at,
        quote.accepted_at,
        quote.changes_requested_at,
        quote.reopened_at
      ].compact.any? { |at| at.to_date >= Date.current - 7.days }
    end
    risk_customers = customers.count do |customer|
      customer.follow_up_overdue? ||
        customer.follow_up_due_today? ||
        (customer.next_follow_up_date.blank? && active_quotes_collection(customer.quotes).any?)
    end

    [
      {
        label: I18n.t("dashboard.logic.operational_risk"),
        value: I18n.t("dashboard.logic.accounts", count: risk_customers),
        tone: risk_customers.positive? ? :danger : :good,
        detail: risk_customers.positive? ? I18n.t("dashboard.logic.follow_up_pressure_attention") : I18n.t("dashboard.logic.no_urgent_account_risk")
      },
      {
        label: I18n.t("dashboard.logic.momentum"),
        value: "#{recent_motion_quotes.count}/#{active_quotes.count.nonzero? || 0}",
        tone: recent_motion_quotes.any? ? :good : :neutral,
        detail: active_quotes.any? ? I18n.t("dashboard.logic.active_quotes_touched") : I18n.t("dashboard.logic.no_active_quotes_yet")
      },
      {
        label: I18n.t("dashboard.logic.observed_engagement"),
        value: "#{viewed_quotes.count}/#{active_quotes.count.nonzero? || 0}",
        tone: viewed_quotes.any? ? :watch : :neutral,
        detail: active_quotes.any? ? I18n.t("dashboard.logic.quotes_with_view_evidence") : I18n.t("dashboard.logic.no_viewable_quote_evidence")
      }
    ]
  end

  def build_recent_quotes(customers)
    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(customers))

    latest_quotes
      .sort_by { |quote| [ -(quote.updated_at || Time.zone.at(0)).to_i, recent_quote_priority(quote) ] }
      .first(6)
      .map do |quote|
        status = quote_display_status(quote)
        view_signal, next_action = recent_quote_signals(quote, status)

        {
          quote: quote,
          quote_no: quote.quote_no,
          display_name: quote.custom_title.presence || quote.quote_items.ordered.first&.product&.name.presence || quote.quote_items.ordered.first&.description.presence,
          customer_name: quote.customer&.name || I18n.t("dashboard.logic.unknown_customer"),
          status: status,
          view_signal: view_signal,
          next_action: next_action,
          total: quote.grand_total,
          currency: quote.currency.to_s.upcase.presence || I18n.t("dashboard.logic.default_currency"),
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
    period_label = period == "month" ? I18n.t("dashboard.logic.period_month") : I18n.t("dashboard.logic.period_week")
    health = kpi_health_state(kind, current_value, change)
    {
      value: current_value,
      trend_text: I18n.t("dashboard.logic.trend_vs_last_period", value: change.round, period: period_label),
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
        { label: I18n.t("dashboard.logic.health.risk"), class: "is-risk" }
      elsif current_value.to_i >= 4 || change >= 10
        { label: I18n.t("dashboard.logic.health.watch"), class: "is-watch" }
      else
        { label: I18n.t("dashboard.logic.health.stable"), class: "is-stable" }
      end
    when :throughput
      if change <= -25
        { label: I18n.t("dashboard.logic.health.risk"), class: "is-risk" }
      elsif change <= -10 || change >= 20
        { label: I18n.t("dashboard.logic.health.watch"), class: "is-watch" }
      else
        { label: I18n.t("dashboard.logic.health.stable"), class: "is-stable" }
      end
    else
      if change <= -20
        { label: I18n.t("dashboard.logic.health.risk"), class: "is-risk" }
      elsif change <= -5 || change >= 15
        { label: I18n.t("dashboard.logic.health.watch"), class: "is-watch" }
      else
        { label: I18n.t("dashboard.logic.health.stable"), class: "is-stable" }
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
        title: I18n.t("dashboard.logic.action.follow_up_due_today_title", name: customer.name),
        detail: I18n.t("dashboard.logic.action.follow_up_due_today_detail"),
        cta_label: I18n.t("dashboard.logic.action.open_customer"),
        cta_path: customer_path(customer),
        cta_method: :get
      }
    end

    customers.select(&:follow_up_overdue?).first(4).each do |customer|
      overdue_days = (Date.current - customer.next_follow_up_date).to_i
      items << {
        priority: "urgent",
        title: I18n.t("dashboard.logic.action.overdue_follow_up_title", name: customer.name),
        detail: I18n.t("dashboard.logic.action.overdue_follow_up_detail", days: overdue_days),
        cta_label: I18n.t("dashboard.logic.action.open_customer"),
        cta_path: customer_path(customer),
        cta_method: :get
      }
    end

    customers.select { |customer| high_value_customer?(customer, metrics) && stalled_customer?(customer) }.first(3).each do |customer|
      items << {
        priority: "urgent",
        title: I18n.t("dashboard.logic.action.high_value_stalled_title", name: customer.name),
        detail: I18n.t("dashboard.logic.action.high_value_stalled_detail"),
        cta_label: I18n.t("dashboard.logic.action.open_customer"),
        cta_path: customer_path(customer),
        cta_method: :get
      }
    end

    customers.select { |customer| customer.last_follow_up_date.blank? || customer.last_follow_up_date < Date.current - 14.days }.first(3).each do |customer|
      items << {
        priority: "watch",
        title: I18n.t("dashboard.logic.action.no_recent_follow_up_title", name: customer.name),
        detail: I18n.t("dashboard.logic.action.no_recent_follow_up_detail"),
        cta_label: I18n.t("dashboard.logic.action.open_customer"),
        cta_path: customer_path(customer),
        cta_method: :get
      }
    end

    customers.select { |customer| customer.next_follow_up_date.blank? }.first(2).each do |customer|
      items << {
        priority: "normal",
        title: I18n.t("dashboard.logic.action.no_follow_up_schedule_title", name: customer.name),
        detail: I18n.t("dashboard.logic.action.no_follow_up_schedule_detail"),
        cta_label: I18n.t("dashboard.logic.action.open_customer"),
        cta_path: customer_path(customer),
        cta_method: :get
      }
    end

    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(customers))
    latest_quotes
      .map { |quote| [ quote, quote_signal_for(quote) ] }
      .select { |(_, signal)| signal.present? && %w[urgent risk watch].include?(signal.priority) }
      .sort_by { |(quote, signal)| [ QuoteSignalService.priority_rank(signal.priority), -(quote.updated_at || Time.zone.at(0)).to_i ] }
      .first(4)
      .each do |quote, signal|
        cta = action_center_quote_signal_cta(quote, signal)
        items << {
          source: "quote_signal",
          quote_id: quote.id,
          recommended_action: signal.recommended_action,
          priority: signal.priority,
          title: "#{signal.label} · #{quote_display_name(quote)}",
          detail: DealRadarService.detail_for_signal(quote, signal),
          cta_label: cta[:label],
          cta_path: cta[:path],
          cta_method: cta[:method]
        }
      end

    order = { "urgent" => 0, "risk" => 1, "watch" => 2, "normal" => 3 }
    items.uniq { |item| item[:title] }.sort_by { |item| [ order.fetch(item[:priority], 9), item[:title] ] }.first(9)
  end

  def action_center_quote_signal_cta(quote, signal)
    action = signal.recommended_action.to_s

    case action
    when "renew_quote", "prepare_revision", "resend_reminder"
      { label: signal.cta_label, path: quote_path(quote), method: :get }
    else
      { label: signal.cta_label, path: quote_path(quote), method: :get }
    end
  end

  def build_decision_snapshot(customers, period)
    latest_quotes = latest_quotes_from_collection(active_quotes_from_customers(customers))
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
    latest_quote = active_quotes_collection(customer.quotes).max_by(&:updated_at)
    latest_quote.present? && latest_quote.updated_at.to_date <= Date.current - 14.days
  end

  def quote_cycle_state(closed_cycle_days)
    return I18n.t("dashboard.logic.health_band.within") if closed_cycle_days.empty?

    average_days = closed_cycle_days.sum.to_f / closed_cycle_days.size
    return I18n.t("dashboard.logic.health_band.within") if average_days <= 14
    return I18n.t("dashboard.logic.health_band.below") if average_days <= 28

    I18n.t("dashboard.logic.health_band.above")
  end

  def revision_state_for(revision_rate)
    return I18n.t("dashboard.logic.health_band.within") if revision_rate <= 25
    return I18n.t("dashboard.logic.health_band.below") if revision_rate <= 45

    I18n.t("dashboard.logic.health_band.above")
  end

  def follow_up_interval_state(avg_follow_up_gap)
    return I18n.t("dashboard.logic.health_band.within") if avg_follow_up_gap <= 7
    return I18n.t("dashboard.logic.health_band.below") if avg_follow_up_gap <= 14

    I18n.t("dashboard.logic.health_band.above")
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
      I18n.t("dashboard.logic.next_action.send_reminder")
    elsif status == "expired"
      I18n.t("dashboard.logic.next_action.create_revision")
    elsif status == "negotiating"
      I18n.t("dashboard.logic.next_action.push_to_close")
    elsif status == "viewed"
      I18n.t("dashboard.logic.next_action.follow_up_now")
    else
      I18n.t("dashboard.logic.next_action.review")
    end
  end

  def recent_quote_signals(quote, status)
    signal = quote_signal_for(quote)
    if status == "draft"
      [
        I18n.t("dashboard.logic.signal.draft_not_shared"),
        { label: I18n.t("dashboard.logic.signal.send_now"), path: edit_quote_path(quote), style: "is-watch" }
      ]
    elsif signal&.type == "not_viewed_7d"
      [
        I18n.t("signals.not_viewed"),
        { label: I18n.t("actions.send_reminder"), path: quote_path(quote), style: "is-attention" }
      ]
    elsif signal&.type == "not_viewed_3d"
      [
        I18n.t("dashboard.logic.signal.sent_no_view_3d"),
        { label: I18n.t("actions.send_reminder"), path: quote_path(quote), style: "is-watch" }
      ]
    elsif signal&.type == "expiring_soon"
      [
        I18n.t("signals.quote_expiring"),
        { label: I18n.t("actions.renew_quote"), path: duplicate_quote_path(quote), style: "is-attention" }
      ]
    elsif signal&.type == "hot_engagement_no_follow_up"
      [
        I18n.t("signals.hot_engagement"),
        { label: I18n.t("actions.follow_up"), path: quote_path(quote), style: "is-primary" }
      ]
    elsif signal&.type == "stalled_negotiation"
      [
        I18n.t("signals.stalled_negotiation"),
        { label: I18n.t("actions.follow_up"), path: quote_path(quote), style: "is-watch" }
      ]
    elsif %w[viewed negotiating].include?(status)
      [
        status == "negotiating" ? I18n.t("dashboard.logic.signal.viewed_in_negotiation") : I18n.t("dashboard.logic.signal.viewed"),
        { label: I18n.t("dashboard.logic.signal.follow_up_today"), path: quote_path(quote), style: "is-primary" }
      ]
    elsif status == "won"
      [
        I18n.t("dashboard.logic.signal.decision_recorded"),
        { label: I18n.t("dashboard.logic.signal.review"), path: quote_path(quote), style: "is-neutral" }
      ]
    elsif status == "lost"
      [
        I18n.t("dashboard.logic.signal.closed_lost"),
        { label: I18n.t("dashboard.logic.signal.review"), path: quote_path(quote), style: "is-neutral" }
      ]
    elsif status == "expired"
      [
        I18n.t("dashboard.logic.signal.expired"),
        { label: I18n.t("dashboard.logic.signal.create_revision"), path: quote_path(quote), style: "is-watch" }
      ]
    else
      [
        I18n.t("dashboard.logic.signal.no_active_signal"),
        { label: recent_quote_next_action(quote, status), path: quote_path(quote), style: "is-neutral" }
      ]
    end
  end

  def quote_push_signal(quote, status, customer)
    signal = quote_signal_for(quote)
    if status == "draft"
      {
        priority: 0,
        state: "watch",
        summary: I18n.t("customers.logic.quote_push_signal.draft.summary"),
        detail: I18n.t("customers.logic.quote_push_signal.draft.detail"),
        label: I18n.t("customers.logic.quote_push_signal.draft.label"),
        path: edit_quote_path(quote),
        method: :get
      }
    elsif signal&.type == "not_viewed_7d"
      {
        priority: 0,
        state: "risk",
        quote_signal: signal,
        summary: I18n.t("signals.not_viewed"),
        detail: I18n.t("signals.detail.not_viewed_7d", days: signal.metadata[:days_since_sent].to_i),
        label: I18n.t("actions.send_reminder")
      }
    elsif signal&.type == "not_viewed_3d"
      {
        priority: 2,
        state: "watch",
        quote_signal: signal,
        summary: I18n.t("signals.not_viewed"),
        detail: I18n.t("signals.detail.not_viewed_3d", days: signal.metadata[:days_since_sent].to_i),
        label: I18n.t("actions.send_reminder")
      }
    elsif signal&.type == "hot_engagement_no_follow_up" || (%w[viewed negotiating].include?(status) && viewed_without_follow_up?(quote, customer))
      {
        priority: 1,
        state: "watch",
        summary: I18n.t("customers.logic.quote_push_signal.viewed_no_follow_up.summary"),
        detail: I18n.t("customers.logic.quote_push_signal.viewed_no_follow_up.detail"),
        label: I18n.t("customers.logic.quote_push_signal.viewed_no_follow_up.label"),
        path: schedule_follow_up_customer_path(customer, days: 3),
        method: :post
      }
    elsif signal&.type == "expiring_soon" || status == "expired"
      {
        priority: 1,
        state: "risk",
        quote_signal: signal,
        summary: I18n.t("customers.logic.quote_push_signal.expired.summary"),
        detail: I18n.t("customers.logic.quote_push_signal.expired.detail"),
        label: I18n.t("customers.logic.quote_push_signal.expired.label")
      }
    else
      {
        priority: 4,
        state: "stable",
        summary: I18n.t("customers.logic.quote_push_signal.no_immediate_action.summary"),
        detail: I18n.t("customers.logic.quote_push_signal.no_immediate_action.detail"),
        label: I18n.t("customers.logic.quote_push_signal.no_immediate_action.label"),
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
      { label: I18n.t("customers.logic.engagement_state.at_risk"), css: "is-risk" }
    elsif latest_signal_at.present? && latest_signal_at.to_date >= Date.current - 7.days
      { label: I18n.t("customers.logic.engagement_state.active"), css: "is-active" }
    elsif latest_signal_at.present? && latest_signal_at.to_date >= Date.current - 21.days
      { label: I18n.t("customers.logic.engagement_state.cooling"), css: "is-cooling" }
    else
      { label: I18n.t("customers.logic.engagement_state.at_risk"), css: "is-risk" }
    end
  end

  def build_customer_operating_signals(customer, quote_cards, latest_signal_at)
    latest_card = quote_cards.max_by { |card| card[:updated_at] || Time.zone.at(0) }
    latest_quote = latest_card&.dig(:quote)
    latest_status = latest_card&.dig(:display_status)
    total_views = quote_cards.sum { |card| card[:quote].quote_shares.sum(&:view_count) }

    risk_signal =
      if customer.follow_up_overdue?
        {
          label: I18n.t("customers.logic.operating_signals.risk.label"),
          value: I18n.t("customers.logic.operating_signals.risk.high"),
          tone: :danger,
          detail: I18n.t("customers.logic.operating_signals.risk.high_detail")
        }
      elsif customer.follow_up_due_today?
        {
          label: I18n.t("customers.logic.operating_signals.risk.label"),
          value: I18n.t("customers.logic.operating_signals.risk.watch"),
          tone: :watch,
          detail: I18n.t("customers.logic.operating_signals.risk.watch_detail")
        }
      elsif customer.next_follow_up_date.blank? && quote_cards.any?
        {
          label: I18n.t("customers.logic.operating_signals.risk.label"),
          value: I18n.t("customers.logic.operating_signals.risk.unscheduled"),
          tone: :watch,
          detail: I18n.t("customers.logic.operating_signals.risk.unscheduled_detail")
        }
      else
        {
          label: I18n.t("customers.logic.operating_signals.risk.label"),
          value: I18n.t("customers.logic.operating_signals.risk.controlled"),
          tone: :good,
          detail: I18n.t("customers.logic.operating_signals.risk.controlled_detail")
        }
      end

    momentum_signal =
      if latest_quote.blank?
        {
          label: I18n.t("customers.logic.operating_signals.momentum.label"),
          value: I18n.t("customers.logic.operating_signals.momentum.no_quotes"),
          tone: :neutral,
          detail: I18n.t("customers.logic.operating_signals.momentum.no_quotes_detail")
        }
      elsif [ latest_quote.updated_at, latest_signal_at ].compact.any? { |at| at.to_date >= Date.current - 7.days }
        {
          label: I18n.t("customers.logic.operating_signals.momentum.label"),
          value: I18n.t("customers.logic.operating_signals.momentum.moving"),
          tone: :good,
          detail: I18n.t("customers.logic.operating_signals.momentum.moving_detail")
        }
      elsif [ latest_quote.updated_at, latest_signal_at ].compact.any? { |at| at.to_date >= Date.current - 21.days }
        {
          label: I18n.t("customers.logic.operating_signals.momentum.label"),
          value: I18n.t("customers.logic.operating_signals.momentum.cooling"),
          tone: :watch,
          detail: I18n.t("customers.logic.operating_signals.momentum.cooling_detail")
        }
      else
        {
          label: I18n.t("customers.logic.operating_signals.momentum.label"),
          value: I18n.t("customers.logic.operating_signals.momentum.stalled"),
          tone: :danger,
          detail: I18n.t("customers.logic.operating_signals.momentum.stalled_detail")
        }
      end

    engagement_signal =
      if total_views.positive? || latest_signal_at.present?
        {
          label: I18n.t("customers.logic.operating_signals.engagement.label"),
          value: total_views.positive? ? I18n.t("customers.logic.operating_signals.engagement.observed") : I18n.t("customers.logic.operating_signals.engagement.indirect"),
          tone: total_views.positive? ? :good : :watch,
          detail: total_views.positive? ? I18n.t("customers.logic.operating_signals.engagement.observed_detail", count: total_views) : I18n.t("customers.logic.operating_signals.engagement.indirect_detail")
        }
      elsif %w[sent viewed negotiating].include?(latest_status)
        {
          label: I18n.t("customers.logic.operating_signals.engagement.label"),
          value: I18n.t("customers.logic.operating_signals.engagement.low_visibility"),
          tone: :neutral,
          detail: I18n.t("customers.logic.operating_signals.engagement.low_visibility_detail")
        }
      else
        {
          label: I18n.t("customers.logic.operating_signals.engagement.label"),
          value: I18n.t("customers.logic.operating_signals.engagement.not_available"),
          tone: :neutral,
          detail: I18n.t("customers.logic.operating_signals.engagement.not_available_detail")
        }
      end

    [ risk_signal, momentum_signal, engagement_signal ]
  end

  def follow_up_text_for(customer)
    if customer.follow_up_overdue?
      I18n.t("customers.logic.follow_up_text.overdue")
    elsif customer.follow_up_due_today?
      I18n.t("customers.logic.follow_up_text.due_today")
    elsif customer.follow_up_status == "upcoming"
      I18n.t("customers.logic.follow_up_text.upcoming")
    else
      I18n.t("customers.logic.follow_up_text.not_scheduled")
    end
  end

  def follow_up_primary_action_for(customer)
    if customer.follow_up_overdue? || customer.follow_up_due_today?
      { label: I18n.t("customers.logic.follow_up_primary_action.mark_followed_today"), path: mark_follow_up_customer_path(customer), method: :post }
    elsif customer.next_follow_up_date.blank?
      { label: I18n.t("customers.logic.follow_up_primary_action.schedule_plus_7d"), path: schedule_follow_up_customer_path(customer, days: 7), method: :post }
    else
      { label: I18n.t("customers.logic.follow_up_primary_action.adjust_follow_up"), path: edit_customer_path(customer), method: :get }
    end
  end

  def build_customer_row_signals(customers, metrics)
    customers.each_with_object({}) do |customer, hash|
      metrics_data = metrics.fetch(customer)
      signal =
        if customer.follow_up_overdue?
          { label: I18n.t("customers.logic.row_signal.follow_today"), klass: "is-danger", row_risk: "risk-high", reason: I18n.t("customers.logic.row_signal.overdue_follow_up") }
        elsif customer.follow_up_due_today?
          { label: I18n.t("customers.logic.row_signal.contact_now"), klass: "is-today", row_risk: "risk-medium", reason: I18n.t("customers.logic.row_signal.due_today") }
        elsif high_value_customer?(customer, metrics) && stalled_customer?(customer)
          { label: I18n.t("customers.logic.row_signal.re_engage"), klass: "is-upcoming", row_risk: "risk-medium", reason: I18n.t("customers.logic.row_signal.high_value_stalled") }
        elsif customer.follow_up_upcoming?
          { label: I18n.t("customers.logic.row_signal.prepare_quote"), klass: "is-upcoming", row_risk: "risk-low", reason: I18n.t("customers.logic.row_signal.due_soon") }
        else
          { label: I18n.t("customers.logic.row_signal.set_schedule"), klass: "is-muted", row_risk: "risk-low", reason: I18n.t("customers.logic.row_signal.no_urgent_risk") }
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
        title: I18n.t("customers.logic.follow_up_tasks.set_next_follow_up_date.title"),
        detail: I18n.t("customers.logic.follow_up_tasks.set_next_follow_up_date.detail"),
        cta_label: nil,
        cta_path: nil
      }
    elsif customer.follow_up_overdue?
      overdue_days = (today - customer.next_follow_up_date).to_i
      tasks << {
        priority: "urgent",
        title: I18n.t("customers.logic.follow_up_tasks.follow_up_overdue.title"),
        detail: I18n.t("customers.logic.follow_up_tasks.follow_up_overdue.detail", days: overdue_days),
        cta_label: nil,
        cta_path: nil
      }
    elsif customer.follow_up_due_today?
      tasks << {
        priority: "today",
        title: I18n.t("customers.logic.follow_up_tasks.follow_up_due_today.title"),
        detail: I18n.t("customers.logic.follow_up_tasks.follow_up_due_today.detail"),
        cta_label: nil,
        cta_path: nil
      }
    else
      days_left = (customer.next_follow_up_date - today).to_i
      tasks << {
        priority: days_left <= 7 ? "upcoming" : "normal",
        title: I18n.t("customers.logic.follow_up_tasks.upcoming_follow_up.title"),
        detail: I18n.t("customers.logic.follow_up_tasks.upcoming_follow_up.detail", days: days_left, date: customer.next_follow_up_date.strftime("%Y-%m-%d")),
        cta_label: nil,
        cta_path: nil
      }
    end

    quote_cards.each do |card|
      quote = card[:quote]
      status = card[:display_status]
      quote_name = quote_display_name(quote)
      next unless %w[sent viewed negotiating draft].include?(status)

      if quote.valid_until.present?
        days_left = (quote.valid_until - today).to_i
        if days_left.negative?
          tasks << {
            priority: "urgent",
            title: I18n.t("customers.logic.follow_up_tasks.quote_expired.title", quote_name: quote_name),
            detail: I18n.t("customers.logic.follow_up_tasks.quote_expired.detail", date: quote.valid_until.strftime("%Y-%m-%d")),
            cta_label: I18n.t("customers.logic.follow_up_tasks.open_quote"),
            cta_path: quote_path(quote)
          }
          next
        elsif days_left <= 3
          tasks << {
            priority: "today",
            title: I18n.t("customers.logic.follow_up_tasks.quote_expiring_soon.title", quote_name: quote_name),
            detail: I18n.t("customers.logic.follow_up_tasks.quote_expiring_soon.detail", days: days_left),
            cta_label: I18n.t("customers.logic.follow_up_tasks.open_quote"),
            cta_path: quote_path(quote)
          }
        end
      end

      if quote.sent_at.present? && quote.viewed_at.blank?
        tasks << {
          priority: "upcoming",
          title: I18n.t("customers.logic.follow_up_tasks.quote_not_viewed_yet.title", quote_name: quote_name),
          detail: I18n.t("customers.logic.follow_up_tasks.quote_not_viewed_yet.detail", sent_at: quote.sent_at.strftime("%Y-%m-%d %H:%M")),
          cta_label: I18n.t("customers.logic.follow_up_tasks.open_quote"),
          cta_path: quote_path(quote)
        }
      end
    end

    priority_order = { "urgent" => 0, "today" => 1, "upcoming" => 2, "normal" => 3 }
    tasks.sort_by { |task| [ priority_order.fetch(task[:priority], 4), task[:title] ] }.first(8)
  end

  def build_customer_timeline(customer, quote_cards, all_quotes = [], follow_up_events = [])
    events = []
    status_lookup = quote_cards.index_by { |card| card[:quote].id }

    events << {
      at: customer.created_at,
      tone: "normal",
      category: "system_activity",
      title: I18n.t("customers.logic.timeline.customer_created_title"),
      detail: I18n.t("customers.logic.timeline.customer_created_detail", name: customer.name)
    }

    explicit_follow_up_dates = Array(follow_up_events).filter_map { |event| event.contacted_at&.to_date }.uniq
    if customer.last_follow_up_date.present? && !explicit_follow_up_dates.include?(customer.last_follow_up_date)
      events << {
        at: customer.last_follow_up_date.in_time_zone.end_of_day,
        tone: "good",
        category: "high_signal",
        title: I18n.t("customers.logic.timeline.follow_up_completed_title"),
        detail: I18n.t("customers.logic.timeline.follow_up_completed_detail", date: customer.last_follow_up_date.strftime("%Y-%m-%d"))
      }
    end

    if customer.next_follow_up_date.present?
      tone = customer.follow_up_overdue? ? "urgent" : (customer.follow_up_due_today? ? "today" : "normal")
      events << {
        at: customer.next_follow_up_date.in_time_zone.beginning_of_day,
        tone: tone,
        category: "system_activity",
        title: I18n.t("customers.logic.timeline.next_follow_up_scheduled_title"),
        detail: customer.next_follow_up_date.strftime("%Y-%m-%d")
      }
    end

    Array(follow_up_events).each do |event|
      actor = event.user&.full_name.presence || event.user&.email
      detail_parts = []
      detail_parts << I18n.t("follow_up.timeline.logged_by", user: actor) if actor.present?
      detail_parts << I18n.t("follow_up.timeline.quote_reference", quote_name: quote_display_name(event.quote)) if event.quote.present?
      detail_parts << event.note.to_s.truncate(160) if event.note.present?

      tone = case event.channel
      when "whatsapp", "email"
        "good"
      when "manual"
        "today"
      else
        "normal"
      end

      events << {
        at: event.contacted_at,
        tone: tone,
        category: "high_signal",
        title: I18n.t("follow_up.timeline.event_title", channel: event.channel_label),
        detail: detail_parts.reject(&:blank?).join(" • ").presence || I18n.t("follow_up.timeline.event_detail_fallback")
      }
    end

    Array(all_quotes).each do |quote|
      card = status_lookup[quote.id]
      display_status = timeline_quote_status(quote, card)
      quote_name = quote_display_name(quote)
      events << {
        at: quote.created_at,
        tone: "normal",
        category: "system_activity",
        title: I18n.t("customers.logic.timeline.quote_created_title", quote_name: quote_name),
        detail: I18n.t("customers.logic.timeline.revision_detail", revision: quote.revision_number)
      }

      if quote.updated_at.present? && quote.updated_at > quote.created_at
        events << {
          at: quote.updated_at,
          tone: "normal",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.quote_updated_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.latest_status_detail", status: I18n.t("quotes.view.form.status_options.#{display_status}", default: display_status.to_s.humanize))
        }
      end

      if quote.sent_at.present?
        events << {
          at: quote.sent_at,
          tone: "today",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.quote_sent_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.quote_sent_detail")
        }
      end

      if quote.viewed_at.present?
        events << {
          at: quote.viewed_at,
          tone: "good",
          category: "high_signal",
          title: I18n.t("customers.logic.timeline.quote_viewed_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.quote_viewed_detail")
        }
      end

      if quote.changes_requested_at.present?
        events << {
          at: quote.changes_requested_at,
          tone: "today",
          category: "high_signal",
          title: I18n.t("customers.logic.timeline.quote_revision_requested_title", quote_name: quote_name),
          detail: quote.changes_request_message.present? ? I18n.t("customers.logic.timeline.client_request_detail", message: quote.changes_request_message) : I18n.t("customers.logic.timeline.customer_requested_updates")
        }
      end

      if quote.accepted_at.present?
        events << {
          at: quote.accepted_at,
          tone: "good",
          category: "high_signal",
          title: I18n.t("customers.logic.timeline.quote_accepted_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.accepted_via_public_link")
        }
      end

      if quote.reopened_at.present?
        events << {
          at: quote.reopened_at,
          tone: "normal",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.quote_reopened_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.quote_reopened_detail")
        }
      end

      if display_status == "won" && quote.accepted_at.blank?
        events << {
          at: quote.updated_at,
          tone: "good",
          category: "high_signal",
          title: I18n.t("customers.logic.timeline.quote_won_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.marked_won_internally")
        }
      end

      if %w[lost expired].include?(display_status)
        tone = display_status == "lost" ? "urgent" : "normal"
        status_detail =
          if display_status == "lost" && quote.loss_reason.present?
            I18n.t("customers.logic.timeline.marked_lost_reason", reason: quote.display_loss_reason)
          elsif display_status == "expired" && quote.stalled_reason.present?
            I18n.t("customers.logic.timeline.expired_pressure_reason", reason: quote.display_stalled_reason)
          else
            I18n.t("customers.logic.timeline.final_status_changed", status: I18n.t("quotes.view.form.status_options.#{display_status}", default: display_status.to_s.humanize))
          end
        events << {
          at: quote.updated_at,
          tone: tone,
          category: display_status == "lost" ? "high_signal" : "system_activity",
          title: I18n.t("customers.logic.timeline.quote_status_title", quote_name: quote_name, status: I18n.t("quotes.view.form.status_options.#{display_status}", default: display_status.to_s.humanize)),
          detail: status_detail
        }
      end

      if display_status == "won" && quote.win_reason.present?
        events << {
          at: quote.updated_at,
          tone: "good",
          category: "high_signal",
          title: I18n.t("customers.logic.timeline.win_reason_captured_title", quote_name: quote_name),
          detail: quote.display_win_reason
        }
      end

      if quote.reminder_sent_at.present?
        events << {
          at: quote.reminder_sent_at,
          tone: "normal",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.reminder_sent_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.reminder_sent_detail")
        }
      end

      shares = quote.quote_shares.to_a
      if shares.any?
        latest_share = shares.max_by(&:created_at)
        events << {
          at: latest_share.created_at,
          tone: "normal",
          category: "system_activity",
          title: shares.size > 1 ? I18n.t("customers.logic.timeline.public_links_shared", count: shares.size) : I18n.t("customers.logic.timeline.public_link_shared"),
          detail: I18n.t("customers.logic.timeline.public_link_generated")
        }

        first_view = shares.filter_map(&:first_viewed_at).min
        if first_view.present?
          events << {
            at: first_view,
            tone: "good",
            category: "high_signal",
            title: I18n.t("customers.logic.timeline.public_link_first_viewed"),
            detail: I18n.t("customers.logic.timeline.viewed_via_public_link")
          }
        end

        latest_view = shares.filter_map(&:last_viewed_at).max
        total_views = shares.sum { |share| share.view_count.to_i }
        if latest_view.present? && total_views.positive?
          events << {
            at: latest_view,
            tone: "normal",
            category: "system_activity",
            title: I18n.t("customers.logic.timeline.public_link_activity"),
            detail: I18n.t("customers.logic.timeline.viewed_times_via_public_link", count: total_views)
          }
        end
      end

      if quote.archived?
        events << {
          at: quote.archived_at,
          tone: "normal",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.quote_archived_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.revision_archived_detail", revision: quote.revision_number)
        }
      end

      if quote.deleted?
        events << {
          at: quote.deleted_at,
          tone: "normal",
          category: "system_activity",
          title: I18n.t("customers.logic.timeline.quote_deleted_title", quote_name: quote_name),
          detail: I18n.t("customers.logic.timeline.quote_deleted_detail")
        }
      end
    end

    deduped = events.uniq { |event| [ event[:title], event[:detail], event[:at]&.to_i ] }
    deduped.sort_by { |event| event[:at] || Time.zone.at(0) }.reverse
  end

  def timeline_quote_status(quote, card = nil)
    return card[:display_status] if card.present?
    return "deleted" if quote.deleted?
    return "archived" if quote.archived?

    quote_display_status(quote)
  end

  def quote_display_name(quote)
    quote.custom_title.presence ||
      quote.quote_items.ordered.first&.product&.name.presence ||
      quote.quote_items.ordered.first&.description.presence ||
      quote.quote_no
  end
end
