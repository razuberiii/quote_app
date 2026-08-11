class InquiryCatalogMatcher
  def initialize(inquiry)
    @inquiry = inquiry
  end

  def call
    products = @inquiry.company.products.with_attached_image.to_a
    Array(@inquiry.extracted_data["products"]).each_with_index.to_h do |requested, index|
      ranked = products.map { |product| candidate(requested, product) }
        .select { |entry| entry[:score].positive? }
        .sort_by { |entry| [ -entry[:score], -entry[:product].quoted_count.to_i, entry[:product].id ] }
        .first(4)
      [ index, ranked ]
    end
  end

  private

  def score(requested, product)
    requested_tokens = tokens([ requested["name"], requested["model"], requested["specifications"]&.values ].join(" "))
    product_tokens = tokens([ product.name, product.sku, product.description, product.default_specification ].join(" "))
    overlap = (requested_tokens & product_tokens).size
    sku_bonus = requested["model"].present? && requested["model"].casecmp(product.sku.to_s).zero? ? 12 : 0
    name_bonus = normalized(requested["name"]).present? && normalized(product.name).include?(normalized(requested["name"])) ? 5 : 0
    spec_bonus = specification_comparison(requested, product)[:matches].size * 2
    overlap + sku_bonus + name_bonus + spec_bonus
  end

  def reasons(requested, product)
    values = []
    values << "Model matches SKU #{product.sku}" if requested["model"].present? && requested["model"].casecmp(product.sku.to_s).zero?
    common = tokens([ requested["name"], requested["specifications"]&.values ].join(" ")) & tokens([ product.name, product.default_specification ].join(" "))
    values << "Shared terms: #{common.first(4).join(', ')}" if common.any?
    comparison = specification_comparison(requested, product)
    values << "Specifications match: #{comparison[:matches].first(3).join(', ')}" if comparison[:matches].any?
    values.presence || [ "Possible catalog match" ]
  end

  def candidate(requested, product)
    comparison = specification_comparison(requested, product)
    {
      product:,
      score: score(requested, product),
      reasons: reasons(requested, product),
      specification_matches: comparison[:matches],
      specification_conflicts: comparison[:conflicts]
    }
  end

  def specification_comparison(requested, product)
    requested_specs = requested.fetch("specifications", {}).to_h.transform_keys { |key| normalized(key) }
    catalog_specs = product.effective_default_specs.to_h do |entry|
      [ normalized(entry[:name]), entry[:value].to_s.strip ]
    end
    matches = []
    conflicts = []
    requested_specs.each do |key, value|
      next if key.blank? || value.blank? || catalog_specs[key].blank?

      if normalized(catalog_specs[key]) == normalized(value)
        matches << key
      else
        conflicts << { key:, requested: value, catalog: catalog_specs[key] }
      end
    end
    { matches:, conflicts: }
  end

  def tokens(value)
    value.to_s.downcase.scan(/[\p{L}\p{N}-]{2,}/).uniq
  end

  def normalized(value)
    value.to_s.downcase.gsub(/[^\p{L}\p{N}]+/, "")
  end
end
