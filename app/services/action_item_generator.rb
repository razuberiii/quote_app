class ActionItemGenerator
  ACTIONABLE_PRIORITIES = %w[urgent risk watch].freeze

  def initialize(user:)
    @user = user
  end

  def call
    candidate_map = build_candidate_map

    candidate_map.each_value do |attrs|
      action_item = @user.action_items.unresolved.find_or_initialize_by(
        action_type: attrs[:action_type],
        reference: attrs[:reference]
      )

      next unless action_item.new_record?

      action_item.save!
    end

    resolve_stale_items(candidate_map.keys)

    @user.action_items.unresolved.includes(:reference).to_a.sort_by do |item|
      [ item.priority_rank, sort_timestamp_for(item), -item.created_at.to_i ]
    end
  end

  private

  def build_candidate_map
    current_quotes.each_with_object({}) do |quote, map|
      outcome_reason_candidate_for(quote).each do |attrs|
        map[candidate_key(attrs[:action_type], attrs[:reference])] = attrs
      end
      candidate_for_quote(quote).each do |attrs|
        map[candidate_key(attrs[:action_type], attrs[:reference])] = attrs
      end
      follow_up_due_candidate_for(quote).each do |attrs|
        map[candidate_key(attrs[:action_type], attrs[:reference])] = attrs
      end
    end
  end

  def outcome_reason_candidate_for(quote)
    return [ candidate_attrs("win_reason_missing", quote) ] if quote.status.to_s == "won" && quote.win_reason.blank?
    return [ candidate_attrs("loss_reason_missing", quote) ] if quote.status.to_s == "lost" && quote.loss_reason.blank?

    []
  end

  def current_quotes
    @current_quotes ||= @user.company.quotes
      .not_archived
      .latest_versions
      .includes(:customer, :quote_shares)
      .to_a
  end

  def candidate_for_quote(quote)
    signal = QuoteSignalService.new(quote).call
    return [] unless ACTIONABLE_PRIORITIES.include?(signal.priority)

    [ candidate_attrs(signal.type, quote) ]
  end

  def follow_up_due_candidate_for(quote)
    customer = quote.customer
    return [] if customer.blank?
    return [] unless latest_quote_for_customer(quote) == quote
    return [] unless customer.follow_up_due_today? || customer.follow_up_overdue?

    [ candidate_attrs("follow_up_due", quote) ]
  end

  def candidate_attrs(action_type, quote)
    { action_type: action_type, reference: quote }
  end

  def candidate_key(action_type, reference)
    "#{action_type}:#{reference.class.name}:#{reference.id}"
  end

  def latest_quote_for_customer(quote)
    @latest_quotes_by_customer ||= current_quotes.group_by(&:customer_id).transform_values do |quotes|
      quotes.max_by { |candidate| candidate.updated_at.to_i }
    end

    @latest_quotes_by_customer[quote.customer_id]
  end

  def resolve_stale_items(active_keys)
    @user.action_items.unresolved.includes(:reference).find_each do |item|
      next if active_keys.include?(candidate_key(item.action_type, item.reference))

      item.update_columns(resolved_at: Time.current, updated_at: Time.current)
    end
  end

  def sort_timestamp_for(item)
    quote = item.reference if item.reference.is_a?(Quote)
    return quote.customer.next_follow_up_date.to_time.to_i if item.action_type == "follow_up_due" && quote&.customer&.next_follow_up_date.present?
    return quote.valid_until.to_time.to_i if item.action_type == "expiring_soon" && quote&.valid_until.present?
    return quote.changes_requested_at.to_i if item.action_type == "revision_requested" && quote&.changes_requested_at.present?
    return quote.last_viewed_at.to_i if item.action_type == "viewed_no_follow_up" && quote&.last_viewed_at.present?
    return quote.sent_at.to_i if %w[not_viewed_3d not_viewed_7d].include?(item.action_type) && quote&.sent_at.present?

    item.created_at.to_i
  end
end
