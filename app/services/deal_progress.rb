class DealProgress
  Result = Data.define(:stage, :stage_label, :action_key, :action_label, :attention, :signal, :signal_at)

  def initialize(quote)
    @quote = quote
  end

  def call
    return result("closed", text("stages.closed"), "view", text("actions.view"), false, closed_signal, @quote.updated_at) if closed?
    return accepted_progress if accepted?
    return live_progress if live?

    draft_progress
  end

  private

  def draft_progress
    if @quote.inquiry.present? && %w[draft processing extracted failed].include?(@quote.inquiry.status)
      result("draft", text("stages.draft"), "review_inquiry", text("actions.review_inquiry"), true, text("signals.inquiry_review"), @quote.inquiry.updated_at)
    elsif @quote.customer.blank?
      result("draft", text("stages.draft"), "confirm_buyer", text("actions.confirm_buyer"), true, text("signals.buyer_missing"), @quote.updated_at)
    elsif @quote.quote_items.empty?
      result("draft", text("stages.draft"), "match_products", text("actions.match_products"), true, text("signals.products_review"), @quote.updated_at)
    elsif readiness_issues.any?
      text = readiness_issues.join(" ").downcase
      label = if text.include?("price")
        text("actions.add_prices")
      elsif text.include?("freight") || text.include?("shipping")
        text("actions.add_freight")
      else
        text("actions.complete_quote")
      end
      result("draft", text("stages.draft"), "complete_quote", label, true, readiness_issues.first, @quote.updated_at)
    elsif published_version && !published_version.delivered?
      result("draft", text("stages.draft"), "choose_delivery", text("actions.choose_delivery"), true, text("signals.ready_to_deliver"), published_version.published_at || published_version.created_at)
    else
      result("draft", text("stages.draft"), "publish", text("actions.publish"), true, text("signals.ready_to_publish"), @quote.updated_at)
    end
  end

  def live_progress
    failed = @quote.version_deliveries.where(status: "failed").order(created_at: :desc).first
    latest_success = @quote.version_deliveries.where(status: %w[sent succeeded externally_sent]).maximum(:delivered_at)
    failed_at = failed&.delivered_at || failed&.created_at
    return result("live", text("stages.live"), "retry_delivery", text("actions.retry_delivery"), true, text("signals.delivery_failed"), failed_at) if failed && (latest_success.blank? || failed_at > latest_success)

    response = @quote.deal_responses.where(status: "open").order(received_at: :desc).first
    if response
      action = case response.kind
      when "returned_excel", "returned_pdf", "buyer_file" then [ "review_returned_file", text("actions.review_file") ]
      when "purchase_order" then [ "review_po", text("actions.review_po") ]
      when "email_reply", "external_message", "phone_note" then [ "record_acceptance", text("actions.review_response") ]
      else [ "prepare_update", text("actions.prepare_update") ]
      end
      return result("live", text("stages.live"), action.first, action.last, true, text("signals.response_received"), response.received_at)
    end
    question = questions.where(replied_at: nil).order(created_at: :desc).first
    return result("live", text("stages.live"), "reply", text("actions.reply"), true, text("signals.buyer_question"), question.created_at) if question

    request = change_requests.where(status: "open").order(created_at: :desc).first
    return result("live", text("stages.live"), "prepare_version", text("actions.prepare_version"), true, text("signals.change_requested"), request.created_at) if request

    if @quote.valid_until.present? && @quote.valid_until <= 1.day.from_now.to_date
      return result("live", text("stages.live"), "follow_up", text("actions.follow_up"), true, text("signals.expiring"), @quote.valid_until.beginning_of_day)
    end

    activity = @quote.buyer_activities.order(created_at: :desc).first
    result("live", text("stages.live"), "wait", text("actions.wait"), false, activity_label(activity), activity&.created_at || @quote.updated_at)
  end

  def accepted_progress
    document = @quote.final_documents.order(created_at: :desc).first
    company = @quote.company
    if company.require_final_document? && document.blank?
      return result("accepted", text("stages.accepted"), "generate_final_document", text("actions.generate_document"), true, text("signals.acceptance_recorded"), @quote.quote_acceptance&.accepted_at)
    end
    if document && !document.sent_at?
      return result("accepted", text("stages.accepted"), "send_final_document", text("actions.send_document"), true, text("signals.document_ready"), document.created_at)
    end
    if company.require_deposit_workflow?
      return result("accepted", text("stages.accepted"), "generate_final_document", text("actions.generate_document"), true, text("signals.payment_document"), @quote.quote_acceptance&.accepted_at) unless document
      return result("accepted", text("stages.accepted"), "confirm_payment", text("actions.confirm_payment"), true, text("signals.awaiting_payment"), document.sent_at || document.created_at) unless document.payment_received_at?
    end
    result("accepted", text("stages.accepted"), "close_won", text("actions.close_won"), true, text("signals.acceptance_complete"), @quote.quote_acceptance&.accepted_at)
  end

  def result(stage, stage_label, action_key, action_label, attention, signal, signal_at)
    Result.new(stage:, stage_label:, action_key:, action_label:, attention:, signal:, signal_at:)
  end

  def text(key)
    I18n.t("self_service.deals.progress.#{key}")
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
    @published_version ||= @quote.quote_revisions.where.not(published_at: nil).ordered.first
  end

  def closed_signal
    @quote.status == "won" ? text("signals.won") : text("signals.closed")
  end

  def activity_label(activity)
    return text("signals.waiting") unless activity

    { "viewed" => text("signals.viewed"), "question" => text("signals.buyer_question"),
      "revision_requested" => text("signals.change_requested"), "accepted" => text("signals.accepted") }.fetch(activity.kind, activity.kind.humanize)
  end
end
