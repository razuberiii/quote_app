class InquiryCatalogMatcher
  def initialize(inquiry)
    @inquiry = inquiry
  end

  def call
    products = @inquiry.company.products.with_attached_image.to_a
    Array(@inquiry.extracted_data["products"]).each_with_index.to_h do |requested, index|
      ranked = products.map { |product| [ product, score(requested, product), reasons(requested, product) ] }
        .select { |_, score, _| score.positive? }.sort_by { |_, score, _| -score }.first(4)
      [ index, ranked.map { |product, score, why| { product: product, score: score, reasons: why } } ]
    end
  end

  private

  def score(requested, product)
    requested_tokens = tokens([ requested["name"], requested["model"], requested["specifications"]&.values ].join(" "))
    product_tokens = tokens([ product.name, product.sku, product.default_specification ].join(" "))
    overlap = (requested_tokens & product_tokens).size
    sku_bonus = requested["model"].to_s.casecmp(product.sku.to_s).zero? ? 8 : 0
    overlap + sku_bonus
  end

  def reasons(requested, product)
    values = []
    values << "Model matches SKU #{product.sku}" if requested["model"].present? && requested["model"].casecmp(product.sku.to_s).zero?
    common = tokens([ requested["name"], requested["specifications"]&.values ].join(" ")) & tokens([ product.name, product.default_specification ].join(" "))
    values << "Shared terms: #{common.first(4).join(', ')}" if common.any?
    values.presence || [ "Possible catalog match" ]
  end

  def tokens(value)
    value.to_s.downcase.scan(/[\p{L}\p{N}-]{2,}/).uniq
  end
end
