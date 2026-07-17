class PurchaseOrderComparator
  COMMERCIAL_FIELDS = {
    "currency" => "currency", "shipping" => "shipping_amount", "discount" => "discount_amount",
    "total" => "total", "payment_terms" => "payment_term", "delivery_terms" => "delivery_notes",
    "incoterm" => "trade_term", "delivery_date" => "delivery_date"
  }.freeze

  def initialize(response)
    @response = response
    @revision = response.quote_revision
  end

  def call
    po = parse(@response.body.to_s)
    changes = compare_items(Array(po["items"])) + compare_commercial(po)
    severity = severity_for(po, changes)
    {
      "po_number" => po["po_number"], "buyer" => po["buyer"], "severity" => severity,
      "changes" => changes, "review_required" => severity != "exact_match",
      "quoted_total" => @revision.total.to_s("F"), "stated_total" => po["total"].to_s,
      "parser" => po.delete("_parser")
    }
  end

  private

  def parse(body)
    parsed = JSON.parse(body)
    parsed.deep_stringify_keys.merge("_parser" => "structured_json") if parsed.is_a?(Hash)
  rescue JSON::ParserError
    values = {}
    body.lines.each do |line|
      key, value = line.split(/[:=]/, 2).map(&:to_s).map(&:strip)
      normalized = key.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_")
      values[normalized] = value if value.present?
    end
    values["total"] ||= body[/\b(?:grand\s+total|total|amount)\s*[:=]?\s*[A-Z]{0,3}\s*([\d,.]+)/i, 1].to_s.delete(",")
    values["currency"] ||= body[/\b(USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\b/i, 1]&.upcase
    values["_parser"] = "key_value_text"
    values
  end

  def compare_items(items)
    expected = Array(@revision.snapshot["quote_items"])
    return [] if items.empty?

    keys = %w[sku description quantity unit unit_price amount specifications]
    max = [ expected.length, items.length ].max
    max.flat_map do |index|
      old_item, new_item = expected[index], items[index]&.deep_stringify_keys
      if old_item.blank?
        [ change("added", "items.#{index}", nil, new_item, true) ]
      elsif new_item.blank?
        [ change("removed", "items.#{index}", item_summary(old_item), nil, true) ]
      else
        keys.filter_map do |field|
          old_value = item_value(old_item, field)
          new_value = new_item[field]
          change("changed", "items.#{index}.#{field}", old_value, new_value, material_item_field?(field)) unless new_value.nil? || equivalent?(old_value, new_value)
        end
      end
    end
  end

  def compare_commercial(po)
    COMMERCIAL_FIELDS.filter_map do |input, snapshot_key|
      next if po[input].nil?
      old_value = snapshot_key == "total" ? @revision.total : @revision.snapshot[snapshot_key]
      change("changed", snapshot_key, old_value, po[input], %w[currency shipping_amount total payment_term delivery_notes trade_term].include?(snapshot_key)) unless equivalent?(old_value, po[input])
    end
  end

  def severity_for(po, changes)
    return "review_required" if po.except("_parser").values.compact_blank.empty?
    return "exact_match" if changes.empty?
    changes.any? { |entry| entry["material"] } ? "material_difference" : "minor_difference"
  end

  def material_item_field?(field)
    %w[sku quantity unit_price amount specifications].include?(field)
  end

  def item_value(item, field)
    return item["sku_snapshot"] if field == "sku"
    return item["unit_snapshot"] if field == "unit"
    return item["quantity"].to_d * item["unit_price"].to_d - item["discount_amount"].to_d if field == "amount"
    return Array(item["specifications"]).map { |row| "#{row['key'] || row['name']}: #{row['value']}" }.join(" | ") if field == "specifications"
    item[field]
  end

  def equivalent?(left, right)
    if left.to_s.match?(/\A-?[\d,.]+\z/) && right.to_s.match?(/\A-?[\d,.]+\z/)
      (left.to_s.delete(",").to_d - right.to_s.delete(",").to_d).abs < BigDecimal("0.01")
    else
      left.to_s.squish.casecmp?(right.to_s.squish)
    end
  end

  def change(kind, path, old_value, new_value, material)
    { "kind" => kind, "path" => path, "old" => old_value, "new" => new_value, "material" => material, "selected" => true }
  end

  def item_summary(item)
    { "sku" => item["sku_snapshot"], "description" => item["description"], "quantity" => item["quantity"], "unit_price" => item["unit_price"] }
  end
end
