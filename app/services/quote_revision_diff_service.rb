class QuoteRevisionDiffService
  def initialize(new_quote:, old_quote:)
    @new_quote = new_quote
    @old_quote = old_quote
  end

  def call
    new_items = snapshot_items(@new_quote)
    old_items = snapshot_items(@old_quote)

    {
      added_items: build_added_items(new_items, old_items),
      removed_items: build_removed_items(new_items, old_items),
      modified_items: build_modified_items(new_items, old_items),
      commercial_changes: build_commercial_changes,
      financial_changes: build_financial_changes,
      total_before: @old_quote.grand_total.to_d,
      total_after: @new_quote.grand_total.to_d
    }
  end

  private

  def snapshot_items(quote)
    occurrences = Hash.new(0)

    quote.quote_items.ordered.map do |item|
      signature = item_signature(item)
      occurrences[signature] += 1

      {
        key: "#{signature}:#{occurrences[signature]}",
        product_name: item_name(item),
        quantity: item.quantity.to_i,
        unit_price: item.unit_price.to_d.round(4),
        line_total: item.line_total.to_d.round(4),
        specifications: normalized_specifications(item),
        addon_charges: normalized_addons(item)
      }
    end
  end

  def item_signature(item)
    if item.product_id.present?
      "product:#{item.product_id}"
    else
      "name:#{normalize_text(item_name(item))}"
    end
  end

  def item_name(item)
    item.product&.name.presence || item.description.presence || "Item"
  end

  def normalize_text(value)
    value.to_s.downcase.gsub(/\s+/, " ").strip
  end

  def build_added_items(new_items, old_items)
    old_keys = old_items.index_by { |item| item[:key] }

    new_items.filter_map do |item|
      next if old_keys.key?(item[:key])

      {
        key: item[:key],
        product_name: item[:product_name],
        quantity_after: item[:quantity],
        unit_price_after: item[:unit_price],
        line_total_after: item[:line_total],
        specifications_after: item[:specifications],
        addon_charges_after: item[:addon_charges]
      }
    end
  end

  def build_removed_items(new_items, old_items)
    new_keys = new_items.index_by { |item| item[:key] }

    old_items.filter_map do |item|
      next if new_keys.key?(item[:key])

      {
        key: item[:key],
        product_name: item[:product_name],
        quantity_before: item[:quantity],
        unit_price_before: item[:unit_price],
        line_total_before: item[:line_total],
        specifications_before: item[:specifications],
        addon_charges_before: item[:addon_charges]
      }
    end
  end

  def build_modified_items(new_items, old_items)
    old_by_key = old_items.index_by { |item| item[:key] }

    new_items.filter_map do |item|
      previous = old_by_key[item[:key]]
      next unless previous
      spec_changes = diff_specifications(previous[:specifications], item[:specifications])
      addon_changes = diff_addons(previous[:addon_charges], item[:addon_charges])
      quantity_changed = previous[:quantity] != item[:quantity]
      unit_price_changed = previous[:unit_price] != item[:unit_price]
      next unless quantity_changed || unit_price_changed || spec_changes[:changed] || addon_changes[:changed]

      {
        key: item[:key],
        product_name: item[:product_name],
        quantity_before: previous[:quantity],
        quantity_after: item[:quantity],
        unit_price_before: previous[:unit_price],
        unit_price_after: item[:unit_price],
        line_total_before: previous[:line_total],
        line_total_after: item[:line_total],
        quantity_changed: quantity_changed,
        unit_price_changed: unit_price_changed,
        spec_changes: spec_changes,
        addon_changes: addon_changes
      }
    end
  end

  def build_commercial_changes
    tracked_fields.filter_map do |field|
      before_value = normalized_field_value(@old_quote.public_send(field))
      after_value = normalized_field_value(@new_quote.public_send(field))
      next if before_value == after_value

      {
        field: field,
        label: field_label(field),
        before: before_value.presence || "-",
        after: after_value.presence || "-"
      }
    end
  end

  def tracked_fields
    %i[
      custom_title
      valid_until
      payment_term
      trade_term
      scope_of_supply
      request_reason
      notes
      terms_text
      delivery_notes
      legal_disclaimer
    ]
  end

  def normalized_field_value(value)
    case value
    when Date
      value.strftime("%Y-%m-%d")
    else
      value.to_s.squish
    end
  end

  def field_label(field)
    {
      custom_title: "Quote Title",
      valid_until: "Valid Until",
      payment_term: "Payment Term",
      trade_term: "Trade Term",
      scope_of_supply: "Scope of Supply",
      request_reason: "Request Reason",
      notes: "Notes",
      terms_text: "Terms",
      delivery_notes: "Delivery Notes",
      legal_disclaimer: "Disclaimer"
    }.fetch(field, field.to_s.humanize)
  end

  def build_financial_changes
    %i[tax_amount shipping_amount discount_amount grand_total].filter_map do |field|
      before_value = @old_quote.public_send(field).to_d.round(4)
      after_value = @new_quote.public_send(field).to_d.round(4)
      next if before_value == after_value

      {
        field: field,
        before: before_value,
        after: after_value
      }
    end
  end

  def normalized_specifications(item)
    item.specification_pairs.filter_map do |pair|
      key = normalize_text(pair[:key])
      value = pair[:value].to_s.strip
      next if key.blank? && value.blank?

      {
        key: key,
        key_display: pair[:key].to_s.strip,
        value: value
      }
    end
  end

  def normalized_addons(item)
    item.addon_charge_entries.filter_map do |entry|
      name_display = entry[:name].to_s.strip
      name = normalize_text(name_display)
      next if name.blank?

      {
        name: name,
        name_display: name_display,
        amount: entry[:amount].to_d.round(4)
      }
    end
  end

  def diff_specifications(before_specs, after_specs)
    before_map = before_specs.index_by { |row| row[:key] }
    after_map = after_specs.index_by { |row| row[:key] }
    keys = (before_map.keys + after_map.keys).uniq

    added = []
    removed = []
    updated = []

    keys.each do |key|
      before_row = before_map[key]
      after_row = after_map[key]

      if before_row.nil?
        added << after_row
        next
      end

      if after_row.nil?
        removed << before_row
        next
      end

      next if before_row[:value].to_s == after_row[:value].to_s

      updated << {
        key: after_row[:key_display].presence || before_row[:key_display].presence || key,
        before: before_row[:value].to_s,
        after: after_row[:value].to_s
      }
    end

    {
      added: added.map { |row| { key: row[:key_display].presence || row[:key], value: row[:value].to_s } },
      removed: removed.map { |row| { key: row[:key_display].presence || row[:key], value: row[:value].to_s } },
      updated: updated,
      changed: added.any? || removed.any? || updated.any?
    }
  end

  def diff_addons(before_addons, after_addons)
    before_map = before_addons.index_by { |row| row[:name] }
    after_map = after_addons.index_by { |row| row[:name] }
    keys = (before_map.keys + after_map.keys).uniq

    added = []
    removed = []
    updated = []

    keys.each do |key|
      before_row = before_map[key]
      after_row = after_map[key]

      if before_row.nil?
        added << after_row
        next
      end

      if after_row.nil?
        removed << before_row
        next
      end

      next if before_row[:amount].to_d == after_row[:amount].to_d

      updated << {
        name: after_row[:name_display].presence || before_row[:name_display].presence || key,
        before: before_row[:amount].to_d,
        after: after_row[:amount].to_d
      }
    end

    {
      added: added.map { |row| { name: row[:name_display].presence || row[:name], amount: row[:amount].to_d } },
      removed: removed.map { |row| { name: row[:name_display].presence || row[:name], amount: row[:amount].to_d } },
      updated: updated,
      changed: added.any? || removed.any? || updated.any?
    }
  end
end
