class QuoteReadinessAudit
  PLACEHOLDER_PATTERN = /(?:lorem ipsum|test product|confirmation required|tbd|todo|example\.com|\.local)\b/i

  def initialize(quote)
    @quote = quote
  end

  def issues
    [].tap do |list|
      list << "Customer is required" if @quote.customer.blank?
      list << "Currency is required" if @quote.currency.blank?
      list << "Validity date is required" if @quote.valid_until.blank?
      list << "Payment terms are required" if @quote.payment_term.blank?
      list << "Incoterm is required" if @quote.trade_term.blank?
      if @quote.trade_term.to_s.match?(/CIF|CFR|DAP|DDP/i)
        list << "Freight is required for #{@quote.trade_term}" unless @quote.shipping_amount.to_d.positive?
        list << "Freight source is required" if @quote.respond_to?(:shipping_price_source) && @quote.shipping_price_source.blank?
      end
      list << "Add at least one product" if @quote.quote_items.empty?
      @quote.quote_items.each_with_index do |item, index|
        label = "Item #{index + 1}"
        list << "#{label}: product name is required" if item.description.blank?
        list << "#{label}: quantity is required" unless item.quantity.to_i.positive?
        list << "#{label}: price is required" unless item.unit_price.to_d.positive?
        if item.respond_to?(:price_source) && (item.price_source.blank? || item.price_source == "unpriced")
          list << "#{label}: a verified price source is required"
        end
        list << "#{label}: configuration price requires confirmation" if item.addon_charge_entries.any? { |addon| addon[:amount].blank? }
      end
      list << "Quotation total must be greater than zero" unless @quote.grand_total.to_d.positive?
      public_text = [ @quote.custom_title, @quote.notes, @quote.terms_text, @quote.delivery_notes, *@quote.quote_items.map(&:description) ].compact.join(" ")
      list << "Remove placeholder or test content" if public_text.match?(PLACEHOLDER_PATTERN)
    end.uniq
  end
end
