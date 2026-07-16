class BuyerSelectionPricer
  Result = Data.define(:selection, :total)

  def initialize(revision:, selection:)
    @revision = revision
    @selection = selection.to_h.deep_stringify_keys
  end

  def call
    normalized = { "plan" => allowed_plan, "quantities" => {}, "accessories" => [] }
    items_total = Array(@revision.snapshot["quote_items"]).each_with_index.sum do |item, index|
      original_quantity = item["quantity"].to_i
      requested_quantity = @selection.dig("quantities", index.to_s).to_i
      quantity = item["selection_mode"] == "selectable" && requested_quantity.positive? ? requested_quantity : original_quantity
      normalized["quantities"][index.to_s] = quantity
      accessories = Array(item["addon_charges"])
      selected_names = Array(@selection["accessories"])
      selected = accessories.select { |addon| selected_names.include?("#{index}:#{addon['name'] || addon[:name]}") }
      normalized["accessories"].concat(selected.map { |addon| "#{index}:#{addon['name'] || addon[:name]}" })
      item["unit_price"].to_d * quantity + selected.sum { |addon| (addon["amount"] || addon[:amount]).to_d }
    end
    total = items_total + @revision.snapshot["shipping_amount"].to_d + @revision.snapshot["tax_amount"].to_d - @revision.snapshot["discount_amount"].to_d
    Result.new(normalized, [ total, 0 ].max.round(2))
  end

  private

  def allowed_plan
    %w[essential recommended complete].include?(@selection["plan"]) ? @selection["plan"] : "recommended"
  end
end
