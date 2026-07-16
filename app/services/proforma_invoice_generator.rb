class ProformaInvoiceGenerator
  def initialize(acceptance:, actor:)
    @acceptance = acceptance
    @actor = actor
  end

  def call
    @acceptance.with_lock do
      raise ActiveRecord::RecordNotFound unless @actor.company_id == @acceptance.company_id
      return @acceptance.proforma_invoice if @acceptance.proforma_invoice

      pi = ProformaInvoice.create!(
        company: @acceptance.company, quote: @acceptance.quote, quote_acceptance: @acceptance,
        created_by: @actor, number: next_number, status: "awaiting_deposit",
        currency: @acceptance.currency, total: @acceptance.total, snapshot: @acceptance.snapshot.deep_dup
      )
      @acceptance.quote.update!(status: "awaiting_deposit")
      pi
    end
  rescue ActiveRecord::RecordNotUnique
    @acceptance.reload.proforma_invoice
  end

  private

  def next_number
    sequence = @acceptance.company.proforma_invoices.count + 1
    "PI-#{Time.current.year}-#{sequence.to_s.rjust(4, '0')}"
  end
end
