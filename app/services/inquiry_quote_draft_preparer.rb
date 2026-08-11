class InquiryQuoteDraftPreparer
  def initialize(inquiry, matches: inquiry.catalog_matches)
    @inquiry = inquiry
    @data = inquiry.extracted_data.deep_stringify_keys
    @matches = matches
  end

  def call
    items = Array(@data["products"]).each_with_index.map do |requested, index|
      candidates = Array(@matches[index]).first(3).map { |match| prepare_candidate(requested, match) }
      { index:, requested:, recommended: candidates.first, candidates: }
    end
    {
      items:,
      matched_count: items.count { |item| item[:recommended].present? },
      priced_count: items.count { |item| item.dig(:recommended, :price_available) },
      attention_count: items.count { |item| item[:recommended].blank? || item.dig(:recommended, :warnings).any? },
      ready_to_create: @inquiry.ready_to_build_quote?
    }
  end

  private

  def prepare_candidate(requested, match)
    product = match.fetch(:product)
    currency_matches = product.price_currency.to_s.casecmp(@data["currency"].to_s).zero?
    price_available = product.default_price.to_d.positive? && currency_matches
    warnings = []
    warnings << "currency_mismatch" if product.default_price.to_d.positive? && !currency_matches
    warnings << "below_moq" if product.moq.to_i.positive? && requested["quantity"].to_d < product.moq
    warnings << "specification_conflict" if match[:specification_conflicts].any?
    requested_specs = requested.fetch("specifications", {}).to_h
    catalog_specs = product.effective_default_specs.to_h { |entry| [ entry[:name].to_s, entry[:value].to_s ] }

    match.merge(
      recommended: match[:score] >= 5 && match[:specification_conflicts].empty?,
      price_available:,
      warnings:,
      proposal: {
        catalog_product_id: product.id,
        name: product.name,
        model: product.sku.presence || requested["model"],
        quantity: requested["quantity"],
        unit: requested["unit"].presence || product.unit,
        specifications: catalog_specs.merge(requested_specs),
        packing: requested["packing"],
        lead_time: requested["lead_time"].presence || product.lead_time,
        unit_price: price_available ? product.default_price.to_s("F") : nil,
        price_source: price_available ? "catalog" : "unpriced"
      }
    )
  end
end
