class QuoteRevisionDiffService
  KEY_LEVEL_ADVANCED_FIELDS = {
    advanced_trade_terms: %w[
      hs_code
      warranty_scope_note
      delivery_commitment_note
      payment_clause_note
    ],
    advanced_logistics: %w[
      container_type
      freight_note
    ]
  }.freeze

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
        description: normalize_text(item.description),
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
      description_changed = previous[:description] != item[:description]
      quantity_changed = previous[:quantity] != item[:quantity]
      unit_price_changed = previous[:unit_price] != item[:unit_price]
      next unless description_changed || quantity_changed || unit_price_changed || spec_changes[:changed] || addon_changes[:changed]

      {
        key: item[:key],
        product_name: item[:product_name],
        description_before: previous[:description],
        description_after: item[:description],
        quantity_before: previous[:quantity],
        quantity_after: item[:quantity],
        unit_price_before: previous[:unit_price],
        unit_price_after: item[:unit_price],
        line_total_before: previous[:line_total],
        line_total_after: item[:line_total],
        description_changed: description_changed,
        quantity_changed: quantity_changed,
        unit_price_changed: unit_price_changed,
        spec_changes: spec_changes,
        addon_changes: addon_changes
      }
    end
  end

  def build_commercial_changes
    standard_changes = tracked_fields.filter_map do |field|
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

    standard_changes +
      advanced_field_changes_for(:advanced_trade_terms) +
      advanced_field_changes_for(:advanced_logistics)
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
    when Hash
      normalized_hash_for_diff(value).to_json
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
      advanced_trade_terms: I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms"),
      advanced_logistics: "Shipping & Logistics",
      request_reason: "Request Reason",
      notes: "Notes",
      terms_text: "Terms",
      delivery_notes: "Delivery Notes",
      legal_disclaimer: "Disclaimer"
    }.fetch(field, field.to_s.humanize)
  end

  def advanced_field_changes_for(section)
    before_state = normalized_advanced_state_for_diff(@old_quote, section)
    after_state = normalized_advanced_state_for_diff(@new_quote, section)
    key_level_keys = KEY_LEVEL_ADVANCED_FIELDS.fetch(section, [])
    changes = []

    key_level_keys.each do |key|
      before_value = before_state.fetch(key, "")
      after_value = after_state.fetch(key, "")
      next if before_value == after_value

      changes << {
        field: "#{section}.#{key}",
        section: section.to_s,
        diff_mode: "key",
        label: advanced_field_label(section, key),
        before: before_value.presence || "-",
        after: after_value.presence || "-"
      }
    end

    before_non_key = before_state.except(*key_level_keys)
    after_non_key = after_state.except(*key_level_keys)
    return changes if before_non_key == after_non_key

    changes << {
      field: section,
      section: section.to_s,
      diff_mode: "section",
      label: field_label(section),
      before: summarize_advanced_section_values(section, before_non_key),
      after: summarize_advanced_section_values(section, after_non_key)
    }

    changes
  end

  def normalized_advanced_state_for_diff(quote, section)
    raw_value = quote.public_send(section)
    source =
      if raw_value.respond_to?(:to_unsafe_h)
        raw_value.to_unsafe_h
      elsif raw_value.is_a?(Hash)
        raw_value
      else
        {}
      end
    allowed_keys =
      case section.to_sym
      when :advanced_trade_terms then Quote::ADVANCED_TRADE_TERMS_KEYS
      when :advanced_logistics then Quote::ADVANCED_LOGISTICS_KEYS
      else []
      end

    allowed_keys.each_with_object({}) do |key, acc|
      next unless source.key?(key) || source.key?(key.to_sym)

      acc[key] = (source[key] || source[key.to_sym]).to_s.squish
    end
  end

  def summarize_advanced_section_values(section, values)
    rows = values.filter_map do |key, value|
      normalized_value = value.to_s.squish
      next if normalized_value.blank?

      "#{advanced_field_label(section, key)}: #{normalized_value}"
    end

    rows.presence&.join(" | ") || "-"
  end

  def advanced_field_label(section, key)
    key_name = key.to_s
    if section.to_sym == :advanced_trade_terms
      {
        "hs_code" => I18n.t("quotes.view.form.hs_code", default: "HS Code"),
        "warranty_scope_note" => I18n.t("quotes.view.show.field_labels.warranty", default: "Warranty"),
        "support_scope_note" => "Support",
        "validity_clause_note" => I18n.t("quotes.view.show.field_labels.validity", default: "Validity"),
        "delivery_commitment_note" => I18n.t("quotes.view.show.field_labels.delivery", default: "Delivery"),
        "payment_clause_note" => I18n.t("quotes.view.show.field_labels.payment_terms", default: "Payment Terms")
      }.fetch(key_name, key_name.humanize)
    else
      {
        "freight_note" => I18n.t("quotes.view.show.field_labels.freight", default: "Freight"),
        "container_type" => I18n.t("quotes.view.show.field_labels.container_type", default: "Container Type"),
        "shipping_scope_note" => I18n.t("quotes.view.show.field_labels.shipping_scope", default: "Shipping Scope"),
        "container_loading_note" => I18n.t("quotes.view.show.field_labels.container_loading", default: "Container Loading")
      }.fetch(key_name, key_name.humanize)
    end
  end

  def normalized_hash_for_diff(value)
    value.to_h.each_with_object({}) do |(key, raw), acc|
      normalized_key = key.to_s
      next if normalized_key.blank?

      normalized_value = raw.to_s.squish
      next if normalized_value.blank?

      acc[normalized_key] = normalized_value
    end.sort.to_h
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
    before_groups = before_specs.group_by { |row| row[:key] }
    after_groups = after_specs.group_by { |row| row[:key] }
    keys = (before_groups.keys + after_groups.keys).uniq

    added = []
    removed = []
    updated = []

    keys.each do |key|
      before_rows = Array(before_groups[key]).dup
      after_rows = Array(after_groups[key]).dup

      unmatched_before, unmatched_after = consume_exact_matches(before_rows, after_rows) do |before_row, after_row|
        before_row[:value].to_s == after_row[:value].to_s
      end

      pair_count = [ unmatched_before.size, unmatched_after.size ].min
      pair_count.times do |idx|
        before_row = unmatched_before[idx]
        after_row = unmatched_after[idx]
        updated << {
          key: after_row[:key_display].presence || before_row[:key_display].presence || key,
          before: before_row[:value].to_s,
          after: after_row[:value].to_s
        }
      end

      unmatched_after.drop(pair_count).each { |row| added << row }
      unmatched_before.drop(pair_count).each { |row| removed << row }
    end

    {
      added: added.map { |row| { key: row[:key_display].presence || row[:key], value: row[:value].to_s } },
      removed: removed.map { |row| { key: row[:key_display].presence || row[:key], value: row[:value].to_s } },
      updated: updated,
      changed: added.any? || removed.any? || updated.any?
    }
  end

  def diff_addons(before_addons, after_addons)
    before_groups = before_addons.group_by { |row| row[:name] }
    after_groups = after_addons.group_by { |row| row[:name] }
    keys = (before_groups.keys + after_groups.keys).uniq

    added = []
    removed = []
    updated = []

    keys.each do |key|
      before_rows = Array(before_groups[key]).dup
      after_rows = Array(after_groups[key]).dup

      unmatched_before, unmatched_after = consume_exact_matches(before_rows, after_rows) do |before_row, after_row|
        before_row[:amount].to_d == after_row[:amount].to_d
      end

      pair_count = [ unmatched_before.size, unmatched_after.size ].min
      pair_count.times do |idx|
        before_row = unmatched_before[idx]
        after_row = unmatched_after[idx]
        updated << {
          name: after_row[:name_display].presence || before_row[:name_display].presence || key,
          before: before_row[:amount].to_d,
          after: after_row[:amount].to_d
        }
      end

      unmatched_after.drop(pair_count).each { |row| added << row }
      unmatched_before.drop(pair_count).each { |row| removed << row }
    end

    {
      added: added.map { |row| { name: row[:name_display].presence || row[:name], amount: row[:amount].to_d } },
      removed: removed.map { |row| { name: row[:name_display].presence || row[:name], amount: row[:amount].to_d } },
      updated: updated,
      changed: added.any? || removed.any? || updated.any?
    }
  end

  def consume_exact_matches(before_rows, after_rows)
    remaining_after = after_rows.dup
    remaining_before = []

    before_rows.each do |before_row|
      match_idx = remaining_after.find_index { |after_row| yield(before_row, after_row) }
      if match_idx
        remaining_after.delete_at(match_idx)
      else
        remaining_before << before_row
      end
    end

    [ remaining_before, remaining_after ]
  end
end
