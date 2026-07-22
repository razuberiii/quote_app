class QuoteLifecycle
  Result = Data.define(:state, :label, :action, :action_label, :signal, :signal_at, :attention)

  def initialize(quote)
    @quote = quote
  end

  def call
    return result("accepted", "accepted", "view", "view", acceptance_signal, @quote.quote_acceptance&.accepted_at, false) if accepted?
    return result("expired", "expired", "view", "view", "expired", @quote.valid_until&.end_of_day, false) if expired?
    return response_result if open_response
    return result("changes", "changes", "revise", "revise", "changes", open_change_request.created_at, true) if open_change_request
    return result("viewed", "viewed", "follow_up", "follow_up", "viewed", latest_view.created_at, true) if latest_view
    return result("sent", "sent", "follow_up", "follow_up", "sent", latest_delivery_time, false) if delivered?
    return result("ready", "ready", "send", "send", "ready", published_version.published_at, true) if published_version
    result("draft", "draft", "complete", "continue", readiness_signal, @quote.updated_at, true)
  end

  private

  def result(state, label_key, action, action_key, signal_key, signal_at, attention)
    Result.new(state:, label: text("states.#{label_key}"), action:, action_label: text("actions.#{action_key}"),
      signal: text("signals.#{signal_key}"), signal_at:, attention:)
  end

  def response_result
    action = open_response.kind.in?(%w[returned_excel returned_pdf buyer_file purchase_order]) ? "review" : "reply"
    result("changes", "changes", action, action, "response", open_response.received_at, true)
  end

  def text(key)
    I18n.t("self_service.quote_core.lifecycle.#{key}")
  end

  def accepted?
    @quote.quote_acceptance.present? || @quote.status.in?(%w[accepted awaiting_deposit won])
  end

  def expired?
    @quote.status.in?(%w[expired archived cancelled lost]) || (@quote.valid_until.present? && @quote.valid_until < Date.current)
  end

  def open_response
    @open_response ||= @quote.deal_responses.where(status: "open").order(received_at: :desc).first
  end

  def open_change_request
    @open_change_request ||= ChangeRequest.where(quote_revision_id: @quote.quote_revisions.select(:id), status: "open").order(created_at: :desc).first
  end

  def latest_view
    @latest_view ||= @quote.buyer_activities.where(kind: "viewed").order(created_at: :desc).first
  end

  def delivered?
    @quote.version_deliveries.where(status: %w[sent succeeded externally_sent]).exists?
  end

  def latest_delivery_time
    @quote.version_deliveries.where(status: %w[sent succeeded externally_sent]).maximum(:delivered_at) || @quote.sent_at
  end

  def published_version
    @published_version ||= @quote.quote_revisions.where.not(published_at: nil).ordered.first
  end

  def readiness_signal
    QuoteReadinessAudit.new(@quote).issues.any? ? "incomplete" : "draft"
  end

  def acceptance_signal
    "accepted"
  end
end
