module DealsHelper
  def deal_title(deal)
    deal.custom_title.presence || deal.quote_items.first&.description.presence || "Commercial proposal"
  end

  def quote_action_path(quote, lifecycle)
    case lifecycle.action
    when "complete", "revise" then edit_quote_path(quote)
    when "send" then quote_path(quote, tab: "versions")
    when "reply", "review" then quote_path(quote, tab: "activity")
    else quote_path(quote)
    end
  end

  def quote_version_label(quote)
    number = quote.quote_revisions.where.not(published_at: nil).maximum(:number)
    number ? "V#{number}" : I18n.t("self_service.quote_core.lifecycle.states.draft")
  end

  def deal_action_path(deal, progress)
    case progress.action_key
    when "review_inquiry" then deal.inquiry ? inquiry_path(deal.inquiry) : edit_quote_path(deal)
    when "confirm_buyer", "match_products", "add_missing_prices", "add_freight", "complete_quote" then edit_quote_path(deal)
    when "publish" then quote_path(deal)
    when "reply" then deal_path(deal, tab: "conversation")
    when "choose_delivery", "retry_delivery" then deliver_deal_path(deal, version_id: deal.quote_revisions.maximum(:id))
    when "review_returned_file", "review_po", "record_acceptance", "prepare_update", "prepare_version" then deal_path(deal, tab: "conversation")
    when "generate_final_document", "send_final_document" then deal_path(deal, tab: "documents")
    when "confirm_payment" then deal.final_documents.order(created_at: :desc).first ? final_document_path(deal.final_documents.order(created_at: :desc).first) : deal_path(deal)
    else deal_path(deal)
    end
  end

  def deal_version_label(deal)
    number = deal.quote_revisions.maximum(:number) || deal.revision_number || 0
    number.to_i.positive? ? "Version #{number}" : "Not published"
  end
end
