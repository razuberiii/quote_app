class QuoteReadinessAudit
  PLACEHOLDER_PATTERN = /(?:lorem ipsum|test product|confirmation required|tbd|todo|example\.com|\.local)\b/i

  def initialize(quote)
    @quote = quote
  end

  def issues
    entries.map { |entry| entry[:label] }
  end

  def entries
    [].tap do |list|
      list << entry(:customer, "studio-cover") if @quote.customer.blank?
      list << entry(:currency, "studio-cover") if @quote.currency.blank?
      list << entry(:validity, "studio-cover") if @quote.valid_until.blank?
      list << entry(:payment, "studio-terms") if @quote.payment_term.blank?
      list << entry(:incoterm, "studio-terms") if @quote.trade_term.blank?
      if @quote.trade_term.to_s.match?(/CIF|CFR|DAP|DDP/i)
        list << entry(:freight, "studio-pricing", term: @quote.trade_term) unless @quote.shipping_amount.to_d.positive?
        list << entry(:freight_source, "studio-pricing") if @quote.respond_to?(:shipping_price_source) && @quote.shipping_price_source.blank?
      end
      list << entry(:product, "studio-products") if @quote.quote_items.empty?
      @quote.quote_items.each_with_index do |item, index|
        number = index + 1
        list << entry(:item_name, "studio-products", number:) if item.description.blank?
        list << entry(:item_quantity, "studio-products", number:) unless item.quantity.to_i.positive?
        list << entry(:item_price, "studio-products", number:) unless item.unit_price.to_d.positive?
        if item.respond_to?(:price_source) && (item.price_source.blank? || item.price_source == "unpriced")
          list << entry(:item_source, "studio-products", number:)
        end
        list << entry(:item_config, "studio-products", number:) if item.addon_charge_entries.any? { |addon| addon[:amount].blank? }
      end
      list << entry(:total, "studio-pricing") unless @quote.grand_total.to_d.positive?
      @quote.custom_field_definitions.select { |field| field[:required] }.each do |field|
        list << entry(:custom_field, "studio-custom-fields", label: field[:label]) if @quote.custom_field_values.to_h[field[:key].to_s].blank?
      end
      public_text = [ @quote.custom_title, @quote.notes, @quote.terms_text, @quote.delivery_notes, *@quote.quote_items.map(&:description) ].compact.join(" ")
      list << entry(:placeholder, "studio-cover") if public_text.match?(PLACEHOLDER_PATTERN)
    end.uniq { |item| item[:label] }
  end

  def t(key, **options) = I18n.t("self_service.readiness.#{key}", **options)

  def entry(key, anchor, **options) = { label: t(key, **options), anchor: anchor }
end
