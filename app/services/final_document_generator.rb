class FinalDocumentGenerator
  TITLES = {
    "proforma_invoice" => "Proforma Invoice", "order_confirmation" => "Order Confirmation",
    "final_quotation" => "Final Quotation", "commercial_offer" => "Commercial Offer"
  }.freeze

  def initialize(acceptance:, actor:, document_type:, custom_title: nil)
    @acceptance = acceptance
    @actor = actor
    @document_type = document_type
    @custom_title = custom_title
  end

  def call
    raise ActiveRecord::RecordNotFound unless @actor.company_id == @acceptance.company_id
    existing = @acceptance.final_documents.find_by(document_type: @document_type, status: %w[draft sent])
    return existing if existing
    title = @document_type == "custom" ? @custom_title.to_s.strip : TITLES.fetch(@document_type)
    raise ArgumentError, "Document title is required" if title.blank?
    sequence = @acceptance.company.final_documents.count + 1
    @acceptance.company.final_documents.create!(
      quote: @acceptance.quote, quote_acceptance: @acceptance, created_by: @actor,
      document_type: @document_type, title:, number: "FD-#{Time.current.year}-#{sequence.to_s.rjust(4, '0')}",
      currency: @acceptance.currency, total: @acceptance.total, snapshot: @acceptance.snapshot.deep_dup
    )
  end
end
