class ProductImportBatchApplier
  class NoCandidatesSelected < StandardError; end

  CURRENCY_ALIASES = {
    "元" => "CNY",
    "人民币" => "CNY",
    "RMB" => "CNY",
    "￥" => "CNY",
    "¥" => "CNY"
  }.freeze

  def initialize(batch:)
    @batch = batch
  end

  def call
    Product.transaction do
      candidates = @batch.product_import_candidates.lock.to_a
      selected = candidates.reject { |candidate| candidate.decision.in?(%w[pending ignore]) }

      # Pressing the import button with an untouched review is an explicit
      # confirmation of the complete batch. Once the user makes any decisions,
      # pending rows remain pending and only their explicit choices are applied.
      if selected.empty? && candidates.any? { |candidate| candidate.decision == "pending" }
        candidates.select { |candidate| candidate.decision == "pending" }.each do |candidate|
          candidate.decision = candidate.matched_product_id? ? "merge" : "create"
          candidate.save!
        end
        selected = candidates.reject { |candidate| candidate.decision == "ignore" }
      end

      raise NoCandidatesSelected if selected.empty?

      selected.each { |candidate| apply_candidate(candidate) }
      @batch.update!(status: "applied")
      selected.size
    end
  end

  private

  def apply_candidate(candidate)
    data = candidate.candidate_data
    product = candidate.decision == "merge" ? candidate.matched_product : nil
    product ||= @batch.company.products.new

    if candidate.decision == "variant" && candidate.matched_product
      data = data.merge(
        "description" => [ data["description"], "Variant of #{candidate.matched_product.name}" ].compact.join(" · ")
      )
    end

    product.assign_attributes(
      name: data["name"],
      sku: data["sku"].presence,
      product_category: data["category"],
      description: data["description"],
      unit: data["unit"],
      moq: data["moq"],
      lead_time: data["lead_time"],
      price_currency: normalized_currency(data["currency"], product.price_currency),
      default_price: data["explicit_price"].presence || product.default_price
    )
    product.save!
    candidate.update!(matched_product: product)
  end

  def normalized_currency(value, fallback)
    currency = CURRENCY_ALIASES.fetch(value.to_s.strip, value.to_s.strip.upcase)
    return currency if currency.in?(Product::PRICE_CURRENCIES)

    fallback.presence_in(Product::PRICE_CURRENCIES) || @batch.company.default_currency.presence_in(Product::PRICE_CURRENCIES) || "USD"
  end
end
