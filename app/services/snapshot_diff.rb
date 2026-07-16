class SnapshotDiff
  def initialize(before, after)
    @before = before.deep_stringify_keys
    @after = after.deep_stringify_keys
  end

  def call
    keys = (@before.keys | @after.keys) & %w[currency tax_amount shipping_amount discount_amount valid_until payment_term trade_term quote_items]
    keys.filter_map do |key|
      next if @before[key] == @after[key]
      { "field" => key, "before" => @before[key], "after" => @after[key] }
    end
  end
end
