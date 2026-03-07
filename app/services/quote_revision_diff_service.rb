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
        unit_price: item.unit_price.to_d.round(4)
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
        product_name: item[:product_name],
        quantity_after: item[:quantity],
        unit_price_after: item[:unit_price]
      }
    end
  end

  def build_removed_items(new_items, old_items)
    new_keys = new_items.index_by { |item| item[:key] }

    old_items.filter_map do |item|
      next if new_keys.key?(item[:key])

      {
        product_name: item[:product_name],
        quantity_before: item[:quantity],
        unit_price_before: item[:unit_price]
      }
    end
  end

  def build_modified_items(new_items, old_items)
    old_by_key = old_items.index_by { |item| item[:key] }

    new_items.filter_map do |item|
      previous = old_by_key[item[:key]]
      next unless previous
      next if previous[:quantity] == item[:quantity] && previous[:unit_price] == item[:unit_price]

      {
        product_name: item[:product_name],
        quantity_before: previous[:quantity],
        quantity_after: item[:quantity],
        unit_price_before: previous[:unit_price],
        unit_price_after: item[:unit_price]
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
      request_reason: "Request Reason",
      notes: "Notes",
      terms_text: "Terms",
      delivery_notes: "Delivery Notes",
      legal_disclaimer: "Disclaimer"
    }.fetch(field, field.to_s.humanize)
  end
end
