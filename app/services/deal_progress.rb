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
      text = readiness_issues.join(" ").downcase
      label = if text.include?("price")
        "Add missing prices"
      elsif text.include?("freight") || text.include?("shipping")
        "Add freight"
      else
        "Complete quote"
      end
      result("draft", "Draft", label.parameterize(separator: "_"), label, true, readiness_issues.first, @quote.updated_at)
    elsif published_version && !published_version.delivered?
      result("draft", "Draft", "choose_delivery", "Choose delivery method", true, "Published Version is ready to deliver", published_version.published_at || published_version.created_at)
    else
      result("draft", "Draft", "publish", "Publish quote", true, "Ready to publish", @quote.updated_at)
    end
  end

  def live_progress
    failed = @quote.version_deliveries.where(status: "failed").order(created_at: :desc).first
    latest_success = @quote.version_deliveries.where(status: %w[sent succeeded externally_sent]).maximum(:delivered_at)
    failed_at = failed&.delivered_at || failed&.created_at
    return result("live", "Live", "retry_delivery", "Retry delivery", true, "Latest delivery failed", failed_at) if failed && (latest_success.blank? || failed_at > latest_success)

    response = @quote.deal_responses.where(status: "open").order(received_at: :desc).first
    if response
      action = case response.kind
      when "returned_excel", "returned_pdf", "buyer_file" then [ "review_returned_file", "Review returned file" ]
      when "purchase_order" then [ "review_po", "Review PO differences" ]
      when "email_reply", "external_message", "phone_note" then [ "record_acceptance", "Review buyer response" ]
      else [ "prepare_update", "Prepare update" ]
      end
      return result("live", "Live", action.first, action.last, true, response.kind.humanize, response.received_at)
    end
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
    document = @quote.final_documents.order(created_at: :desc).first
    company = @quote.company
    if company.require_final_document? && document.blank?
      return result("accepted", "Accepted", "generate_final_document", "Generate final document", true, "Acceptance recorded", @quote.quote_acceptance&.accepted_at)
    end
    if document && !document.sent_at?
      return result("accepted", "Accepted", "send_final_document", "Send final document", true, "Final document is ready", document.created_at)
    end
    if company.require_deposit_workflow?
      return result("accepted", "Accepted", "generate_final_document", "Generate final document", true, "Payment workflow requires a final document", @quote.quote_acceptance&.accepted_at) unless document
      return result("accepted", "Accepted", "confirm_payment", "Confirm payment", true, "Awaiting payment", document.sent_at || document.created_at) unless document.payment_received_at?
    end
    result("accepted", "Accepted", "close_won", "Close as won", true, "Commercial acceptance is complete", @quote.quote_acceptance&.accepted_at)
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
    @quote.version_deliveries.where(status: %w[sent succeeded externally_sent]).exists? || %w[sent viewed revision_requested negotiating expired].include?(@quote.status)
  end

  def accepted?
    @quote.quote_acceptance.present? || %w[accepted awaiting_deposit].include?(@quote.status)
  end

  def closed?
    %w[won lost cancelled archived].include?(@quote.status) || (@quote.respond_to?(:deleted_at) && @quote.deleted_at.present?)
  end

  def published_version
    @published_version ||= @quote.quote_revisions.ordered.first
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
