class ActionItemGenerator
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
      candidate_for_quote(quote).each do |attrs|
        map[candidate_key(attrs[:action_type], attrs[:reference])] = attrs
      end
    end
  end

  def current_quotes
    @current_quotes ||= @user.company.quotes
      .not_archived
      .latest_versions
      .includes(:customer, :quote_shares)
      .to_a
  end

  def candidate_for_quote(quote)
    [].tap do |items|
      items << candidate_attrs("quote_viewed", quote) if quote_viewed?(quote)
      items << candidate_attrs("quote_not_viewed", quote) if quote_not_viewed?(quote)
      items << candidate_attrs("quote_expiring", quote) if quote_expiring?(quote)
      items << candidate_attrs("revision_requested", quote) if revision_requested?(quote)
    end
  end

  def candidate_attrs(action_type, quote)
    { action_type: action_type, reference: quote }
  end

  def candidate_key(action_type, reference)
    "#{action_type}:#{reference.class.name}:#{reference.id}"
  end

  def quote_viewed?(quote)
    quote.viewed_at.present? &&
      %w[viewed negotiating sent].include?(quote.workflow_state)
  end

  def quote_not_viewed?(quote)
    quote.sent_at.present? &&
      quote.viewed_at.blank? &&
      quote.sent_at <= 3.days.ago &&
      quote.workflow_state == "sent"
  end

  def quote_expiring?(quote)
    quote.valid_until.present? &&
      quote.valid_until >= Date.current &&
      quote.valid_until <= 2.days.from_now.to_date &&
      Quote::OPEN_STATUSES.include?(quote.status.to_s)
  end

  def revision_requested?(quote)
    quote.changes_requested_at.present? &&
      %w[negotiating viewed sent].include?(quote.workflow_state)
  end

  def resolve_stale_items(active_keys)
    @user.action_items.unresolved.includes(:reference).find_each do |item|
      next if active_keys.include?(candidate_key(item.action_type, item.reference))

      item.update!(resolved_at: Time.current)
    end
  end

  def sort_timestamp_for(item)
    quote = item.reference if item.reference.is_a?(Quote)
    return quote.valid_until.to_time.to_i if item.action_type == "quote_expiring" && quote&.valid_until.present?
    return quote.changes_requested_at.to_i if item.action_type == "revision_requested" && quote&.changes_requested_at.present?
    return quote.viewed_at.to_i if item.action_type == "quote_viewed" && quote&.viewed_at.present?
    return quote.sent_at.to_i if item.action_type == "quote_not_viewed" && quote&.sent_at.present?

    item.created_at.to_i
  end
end
