module DealsHelper
  def deal_title(deal)
    deal.custom_title.presence || deal.quote_items.first&.description.presence || "Commercial proposal"
  end

  def deal_action_path(deal, progress)
    case progress.action_key
    when "review_inquiry" then deal.inquiry ? inquiry_path(deal.inquiry) : edit_quote_path(deal)
    when "confirm_buyer", "match_products", "add_missing_prices", "complete_quote" then edit_quote_path(deal)
    when "publish" then quote_path(deal)
    when "reply" then deal_path(deal, tab: "conversation")
    when "prepare_version" then quote_path(deal, anchor: "buyer-inbox")
    when "generate_pi", "send_pi" then deal_path(deal, tab: "documents")
    when "confirm_deposit" then deal.proforma_invoice ? proforma_invoice_path(deal.proforma_invoice) : deal_path(deal)
    else deal_path(deal)
    end
  end

  def deal_version_label(deal)
    number = deal.quote_revisions.maximum(:number) || deal.revision_number || 0
    number.to_i.positive? ? "Version #{number}" : "Not published"
  end
end
