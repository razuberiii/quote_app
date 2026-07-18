class QuoteReadinessAudit
  PLACEHOLDER_PATTERN = /(?:lorem ipsum|test product|confirmation required|tbd|todo|example\.com|\.local)\b/i

  def initialize(quote)
    @quote = quote
  end

  def issues
    [].tap do |list|
      list << t(:customer) if @quote.customer.blank?
      list << t(:currency) if @quote.currency.blank?
      list << t(:validity) if @quote.valid_until.blank?
      list << t(:payment) if @quote.payment_term.blank?
      list << t(:incoterm) if @quote.trade_term.blank?
      if @quote.trade_term.to_s.match?(/CIF|CFR|DAP|DDP/i)
        list << t(:freight, term: @quote.trade_term) unless @quote.shipping_amount.to_d.positive?
        list << t(:freight_source) if @quote.respond_to?(:shipping_price_source) && @quote.shipping_price_source.blank?
      end
      list << t(:product) if @quote.quote_items.empty?
      @quote.quote_items.each_with_index do |item, index|
        number = index + 1
        list << t(:item_name, number:) if item.description.blank?
        list << t(:item_quantity, number:) unless item.quantity.to_i.positive?
        list << t(:item_price, number:) unless item.unit_price.to_d.positive?
        if item.respond_to?(:price_source) && (item.price_source.blank? || item.price_source == "unpriced")
          list << t(:item_source, number:)
        end
        list << t(:item_config, number:) if item.addon_charge_entries.any? { |addon| addon[:amount].blank? }
      end
      list << t(:total) unless @quote.grand_total.to_d.positive?
      public_text = [ @quote.custom_title, @quote.notes, @quote.terms_text, @quote.delivery_notes, *@quote.quote_items.map(&:description) ].compact.join(" ")
      list << t(:placeholder) if public_text.match?(PLACEHOLDER_PATTERN)
    end.uniq
  end

  def t(key, **options) = I18n.t("self_service.readiness.#{key}", **options)
end
