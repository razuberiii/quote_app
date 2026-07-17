class ReturnedVersionComparator
  FIELDS = %w[sku description specifications quantity unit unit_price discount amount].freeze

  def initialize(response)
    @response = response
    @revision = response.quote_revision
  end

  def call
    parsed = PublishedWorkbookParser.new(@response.attachment).call
    source_valid = parsed.metadata["deal_id"].to_i == @revision.quote_id && parsed.metadata["version_id"].to_i == @revision.id
    expected = Array(@revision.snapshot["quote_items"])
    changes = []
    max = [ expected.length, parsed.items.length ].max
    max.times do |index|
      old_item = expected[index]
      new_item = parsed.items[index]
      if old_item.blank?
        changes << change("added", "items.#{index}", nil, new_item)
      elsif new_item.blank?
        changes << change("removed", "items.#{index}", summarized(old_item), nil)
      else
        FIELDS.each do |field|
          old_value = expected_value(old_item, field)
          new_value = new_item[field]
          changes << change("changed", "items.#{index}.#{field}", old_value, new_value) unless equivalent?(old_value, new_value)
        end
      end
    end
    commercial_changes(parsed.commercial).each { |entry| changes << entry }
    { "source_valid" => source_valid, "source_version_id" => parsed.metadata["version_id"],
      "changes" => changes, "unsafe_cells" => parsed.unsafe_cells, "review_required" => changes.any? || parsed.unsafe_cells.any?,
      "severity" => changes.any? ? "material_difference" : "exact_match" }
  end

  private

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

  def change(kind, path, old_value, new_value)
    { "kind" => kind, "path" => path, "old" => old_value, "new" => new_value, "selected" => kind != "unsafe" }
  end

  def summarized(item)
    { "sku" => item["sku_snapshot"], "description" => item["description"], "quantity" => item["quantity"], "unit_price" => item["unit_price"] }
  end
end
