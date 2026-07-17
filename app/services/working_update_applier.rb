class WorkingUpdateApplier
  def initialize(response:, selected_paths:)
    @response = response
    @quote = response.quote
    @paths = Array(selected_paths)
  end

  def call
    @quote.with_lock do
      changes.each do |entry|
        next unless @paths.include?(entry["path"])
        apply(entry)
      end
      @quote.update!(status: "draft", studio_state: "draft", sent_at: nil)
      @response.update!(status: "applied", extracted_changes: { "applied_paths" => @paths, "applied_at" => Time.current.iso8601 })
    end
    @quote
  end

  private

  def changes
    Array(@response.difference_review["changes"])
  end

  def apply(entry)
    if (match = entry["path"].match(/\Aitems\.(\d+)\z/))
      return apply_item_change(entry, match[1].to_i)
    end
    if (match = entry["path"].match(/\Aitems\.(\d+)\.(.+)\z/))
      item = @quote.quote_items.ordered[match[1].to_i]
      return unless item
      attribute = { "sku" => :sku_snapshot, "unit" => :unit_snapshot, "discount" => :discount_amount,
        "specifications" => :specifications_text }.fetch(match[2], match[2]).to_sym
      value = entry["new"]
      value = value.to_i if attribute == :quantity
      item.update!(attribute => value) if item.respond_to?("#{attribute}=")
    elsif %w[shipping_amount discount_amount tax_amount trade_term payment_term delivery_notes currency].include?(entry["path"])
      @quote.update!(entry["path"] => entry["new"])
    end
  end

  def apply_item_change(entry, index)
    if entry["kind"] == "removed"
      @quote.quote_items.ordered[index]&.destroy!
    elsif entry["kind"] == "added"
      source = entry["new"].to_h
      @quote.quote_items.create!(
        product: @quote.company.products.find_by(sku: source["sku"]),
        sku_snapshot: source["sku"], description: source["description"].presence || "Buyer requested item",
        quantity: source["quantity"].to_i.clamp(1, 999_999), unit_snapshot: source["unit"].presence || "unit",
        unit_price: source["unit_price"].to_d.positive? ? source["unit_price"].to_d : BigDecimal("0.01"),
        discount_amount: source["discount"].to_d, specifications_text: source["specifications"], price_source: "manual"
      )
    end
  end
end
