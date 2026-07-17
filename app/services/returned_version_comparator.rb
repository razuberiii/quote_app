class ReturnedVersionComparator
  FIELDS = %w[sku description specifications quantity unit unit_price discount amount].freeze

  def initialize(response)
    @response = response
    @revision = response.quote_revision
  end

  def call
    parsed = PublishedWorkbookParser.new(@response.attachment).call
    source_valid = parsed.metadata["deal_id"].to_i == @revision.quote_id &&
      parsed.metadata["version_id"].to_i == @revision.id &&
      ActiveSupport::SecurityUtils.secure_compare(parsed.metadata["secure_fingerprint"].to_s, expected_fingerprint)
    expected = Array(@revision.snapshot["quote_items"])
    changes = []
    matched_expected = []
    parsed.items.each_with_index do |new_item, returned_index|
      match = match_item(expected, new_item, matched_expected)
      if match
        index, old_item, confidence = match
        matched_expected << index
        FIELDS.each do |field|
          old_value = expected_value(old_item, field)
          new_value = new_item[field]
          changes << change("changed", "items.#{index}.#{field}", old_value, new_value,
            match_confidence: confidence, item_id: old_item["id"]) unless equivalent?(old_value, new_value)
        end
      else
        changes << change("added", "items.new_#{returned_index}", nil, new_item, match_confidence: "unmatched")
      end
    end
    expected.each_with_index { |item, index| changes << change("removed", "items.#{index}", summarized(item), nil, match_confidence: "not_returned") unless matched_expected.include?(index) }
    commercial_changes(parsed.commercial).each { |entry| changes << entry }
    { "source_valid" => source_valid, "source_version_id" => parsed.metadata["version_id"],
      "changes" => changes, "unsafe_cells" => parsed.unsafe_cells, "review_required" => changes.any? || parsed.unsafe_cells.any?,
      "severity" => changes.any? ? "material_difference" : "exact_match" }
  end

  private

  def expected_fingerprint
    Digest::SHA256.hexdigest(canonical(@revision.snapshot).to_json)
  end

  def canonical(value)
    return value.keys.sort.to_h { |key| [ key, canonical(value[key]) ] } if value.is_a?(Hash)
    return value.map { |entry| canonical(entry) } if value.is_a?(Array)
    value
  end

  def match_item(expected, returned, used)
    candidates = expected.each_with_index.reject { |_item, index| used.include?(index) }
    line_id = returned["line_id"].to_s
    exact_id = candidates.find { |item, _index| item["id"].to_s == line_id }
    return [ exact_id[1], exact_id[0], "line_id" ] if exact_id
    exact_sku = candidates.find { |item, _index| item["sku_snapshot"].to_s.casecmp?(returned["sku"].to_s) && returned["sku"].present? }
    return [ exact_sku[1], exact_sku[0], "sku" ] if exact_sku
    descriptive = candidates.find do |item, _index|
      item["description"].to_s.squish.casecmp?(returned["description"].to_s.squish) &&
        item["unit_snapshot"].to_s.casecmp?(returned["unit"].to_s)
    end
    return [ descriptive[1], descriptive[0], "description_unit" ] if descriptive
    description_only = candidates.find do |item, _index|
      returned["description"].present? && item["description"].to_s.squish.casecmp?(returned["description"].to_s.squish)
    end
    return [ description_only[1], description_only[0], "description_only" ] if description_only
    nil
  end

  def commercial_changes(values)
    mapping = { "Shipping" => "shipping_amount", "Discount" => "discount_amount", "Tax" => "tax_amount",
      "Total" => "total", "Incoterm" => "trade_term", "Payment terms" => "payment_term", "Delivery terms" => "delivery_notes" }
    mapping.filter_map do |label, key|
      old_value = key == "total" ? @revision.total : @revision.snapshot[key]
      new_value = values[label]
      change("changed", key, old_value, new_value) unless new_value.nil? || equivalent?(old_value, new_value)
    end
  end

  def expected_value(item, field)
    return item["sku_snapshot"] if field == "sku"
    return item["unit_snapshot"] if field == "unit"
    return Array(item["specifications"]).map { |spec| "#{spec['key'] || spec['name']}: #{spec['value']}" }.join(" | ") if field == "specifications"
    return item["quantity"].to_d * item["unit_price"].to_d - item["discount_amount"].to_d if field == "amount"
    item[field == "discount" ? "discount_amount" : field]
  end

  def equivalent?(left, right)
    if left.to_s.match?(/\A-?\d+(\.\d+)?\z/) && right.to_s.match?(/\A-?\d+(\.\d+)?\z/)
      (left.to_d - right.to_d).abs < 0.01
    else
      left.to_s.squish == right.to_s.squish
    end
  end

  def change(kind, path, old_value, new_value, match_confidence: nil, item_id: nil)
    { "kind" => kind, "path" => path, "old" => old_value, "new" => new_value,
      "match_confidence" => match_confidence, "item_id" => item_id, "selected" => kind != "unsafe" }.compact
  end

  def summarized(item)
    { "sku" => item["sku_snapshot"], "description" => item["description"], "quantity" => item["quantity"], "unit_price" => item["unit_price"] }
  end
end
