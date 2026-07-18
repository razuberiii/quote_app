class InquiryGuidance
  Item = Data.define(:label, :level, :complete, :reason)
  LEVELS = %i[now before_publish recommended optional].freeze

  def initialize(inquiry)
    @inquiry = inquiry
    @data = inquiry.extracted_data.deep_stringify_keys
  end

  def items
    products = Array(@data["products"])
    [
      Item.new("确认买家公司", :now, @data["customer"].present?, "用于创建本次 Deal 的买家记录"),
      Item.new("确认报价币种", :now, @data["currency"].present?, "所有价格必须使用明确币种"),
      Item.new("确认商品名称与数量", :now, products.any? && products.all? { |item| item["name"].present? && item["quantity"].to_d.positive? }, "完成后即可创建 Working draft"),
      Item.new("补充可靠单价与价格来源", :before_publish, products.any? && products.all? { |item| item["unit_price"].to_d.positive? && item["price_source"].present? && item["price_source"] != "unpriced" }, "可以稍后在 Quote Studio 完成"),
      Item.new("确认运费与来源", :before_publish, freight_complete?, "CIF、CFR、DAP、DDP 报价发布前需要"),
      Item.new("补充规格、包装和交期", :recommended, products.any? && products.all? { |item| item["specifications"].present? && item["packing"].present? && item["lead_time"].present? }, "帮助买家更快判断，但不阻止创建 Deal"),
      Item.new("关联 Library 商品", :optional, products.any? && products.all? { |item| item["catalog_product_id"].present? }, "可全部保持为 Deal-only item")
    ]
  end

  def next_item = items.find { |item| item.level == :now && !item.complete }

  private

  def freight_complete?
    term = @data.dig("commercial_terms", "incoterm").to_s.upcase
    return true unless term.in?(%w[CIF CFR CPT CIP DAP DPU DDP])
    @data.dig("commercial_terms", "freight_amount").to_d.positive? && @data.dig("commercial_terms", "freight_source").present?
  end
end
