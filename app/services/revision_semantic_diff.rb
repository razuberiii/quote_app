class RevisionSemanticDiff
  Result = Data.define(:product_changes, :commercial_changes, :total_delta)
  PRODUCT_FIELDS = %w[quantity unit_price discount_amount specifications addon_charges].freeze
  COMMERCIAL_FIELDS = %w[shipping_amount discount_amount tax_amount payment_term trade_term valid_until delivery_notes terms_text].freeze

  def initialize(previous:, current:)
    @previous = previous&.snapshot.to_h
    @current = current.snapshot.to_h
    @current_revision = current
  end

  def call
    Result.new(product_changes, commercial_changes, @current_revision.total.to_d - previous_total)
  end

  private

  def product_changes
    before = Array(@previous["quote_items"])
    after = Array(@current["quote_items"])
    keys = (before + after).map { |item| identity(item) }.uniq
    keys.filter_map do |key|
      old_item = before.find { |item| identity(item) == key }
      new_item = after.find { |item| identity(item) == key }
      if old_item.nil?
        { kind: "added", name: item_name(new_item), fields: [ field("Product", nil, item_name(new_item)) ] }
      elsif new_item.nil?
        { kind: "removed", name: item_name(old_item), fields: [ field("Product", item_name(old_item), nil) ] }
      else
        changes = PRODUCT_FIELDS.filter_map do |attribute|
          old_value, new_value = display_value(old_item[attribute]), display_value(new_item[attribute])
          field(attribute.humanize, old_value, new_value) unless equivalent?(old_value, new_value)
        end
        { kind: "changed", name: item_name(new_item), fields: changes } if changes.any?
      end
    end
  end

  def commercial_changes
    COMMERCIAL_FIELDS.filter_map do |attribute|
      old_value, new_value = display_value(@previous[attribute]), display_value(@current[attribute])
      field(attribute.humanize, old_value, new_value) unless equivalent?(old_value, new_value)
    end
  end

  def identity(item)
    item["product_id"].presence || item["sku_snapshot"].presence || item["description"]
  end

  def item_name(item)
    item["product_name"].presence || item["description"].presence || item["sku_snapshot"].presence || "Quoted item"
  end

  def display_value(value)
    return value.map { |row| row.is_a?(Hash) ? "#{row['key'] || row['name']}: #{row['value'] || row['amount']}" : row }.join(" · ") if value.is_a?(Array)
    value
  end

  def equivalent?(left, right)
    left.to_s.squish == right.to_s.squish
  end

  def field(label, before, after)
    { label:, before:, after: }
  end

  def previous_total
    @current_revision.quote.quote_revisions.where("number < ?", @current_revision.number).ordered.first&.total.to_d
  end
end
