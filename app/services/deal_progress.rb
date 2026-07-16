class DealProgress
  Result = Data.define(:stage, :stage_label, :action_key, :action_label, :attention, :signal, :signal_at)

  def initialize(quote)
    @quote = quote
  end

  def call
    return result("closed", "Closed", "view", "View deal", false, closed_signal, @quote.updated_at) if closed?
    return accepted_progress if accepted?
    return live_progress if live?

    draft_progress
  end

  private

  def draft_progress
    if @quote.inquiry.present? && %w[draft processing extracted failed].include?(@quote.inquiry.status)
      result("draft", "Draft", "review_inquiry", "Review inquiry", true, "Inquiry needs review", @quote.inquiry.updated_at)
    elsif @quote.customer.blank?
      result("draft", "Draft", "confirm_buyer", "Confirm buyer", true, "Buyer is missing", @quote.updated_at)
    elsif @quote.quote_items.empty?
      result("draft", "Draft", "match_products", "Match products", true, "Products need confirmation", @quote.updated_at)
    elsif readiness_issues.any?
      label = readiness_issues.any? { |issue| issue.to_s.downcase.include?("price") } ? "Add missing prices" : "Complete quote"
      result("draft", "Draft", label.parameterize(separator: "_"), label, true, readiness_issues.first, @quote.updated_at)
    else
      result("draft", "Draft", "publish", "Publish quote", true, "Ready to publish", @quote.updated_at)
    end
  end

  def live_progress
    question = questions.where(replied_at: nil).order(created_at: :desc).first
    return result("live", "Live", "reply", "Reply to buyer", true, "Buyer asked a question", question.created_at) if question

    request = change_requests.where(status: "open").order(created_at: :desc).first
    return result("live", "Live", "prepare_version", "Prepare new version", true, "Buyer requested changes", request.created_at) if request

    if @quote.valid_until.present? && @quote.valid_until <= 1.day.from_now.to_date
      return result("live", "Live", "follow_up", "Follow up", true, "Quote expires soon", @quote.valid_until.beginning_of_day)
    end

    activity = @quote.buyer_activities.order(created_at: :desc).first
    result("live", "Live", "wait", "Wait for buyer", false, activity_label(activity), activity&.created_at || @quote.updated_at)
  end

  def accepted_progress
    pi = @quote.proforma_invoice
    return result("accepted", "Accepted", "generate_pi", "Generate PI", true, "Acceptance recorded", @quote.quote_acceptance&.accepted_at) unless pi
    return result("accepted", "Accepted", "send_pi", "Send PI", true, "PI is ready", pi.created_at) unless pi.sent_at?
    return result("accepted", "Accepted", "confirm_deposit", "Confirm deposit", true, "Awaiting deposit", pi.sent_at) unless pi.deposit_received_at?

    result("accepted", "Accepted", "close_won", "Close as won", true, "Deposit received", pi.deposit_received_at)
  end

  def result(stage, stage_label, action_key, action_label, attention, signal, signal_at)
    Result.new(stage:, stage_label:, action_key:, action_label:, attention:, signal:, signal_at:)
  end

  def questions
    BuyerQuestion.where(quote_revision_id: @quote.quote_revisions.select(:id))
  end

  def change_requests
    ChangeRequest.where(quote_revision_id: @quote.quote_revisions.select(:id))
  end

  def readiness_issues
    @readiness_issues ||= QuoteReadinessAudit.new(@quote).issues
  end

  def live?
    @quote.quote_revisions.exists? || %w[sent viewed revision_requested negotiating expired].include?(@quote.status)
  end

  def accepted?
    @quote.quote_acceptance.present? || %w[accepted awaiting_deposit].include?(@quote.status)
  end

  def closed?
    %w[won lost archived].include?(@quote.status) || (@quote.respond_to?(:deleted_at) && @quote.deleted_at.present?)
  end

  def closed_signal
    @quote.status == "won" ? "Won" : @quote.status.to_s.humanize
  end

  def activity_label(activity)
    return "Waiting for buyer" unless activity

    { "viewed" => "Buyer viewed the quote", "question" => "Buyer asked a question",
      "revision_requested" => "Buyer requested changes", "accepted" => "Buyer accepted" }.fetch(activity.kind, activity.kind.humanize)
  end
end
