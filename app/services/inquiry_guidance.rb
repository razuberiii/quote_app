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
      Item.new("确认买家公司", :now, @data["customer"].present?, "报价单需要显示买家公司"),
      Item.new("确认报价币种", :now, @data["currency"].present?, "所有价格必须使用明确币种"),
      Item.new("确认商品名称与数量", :now, products.any? && products.all? { |item| item["name"].present? && item["quantity"].to_d.positive? }, "确认后即可创建报价草稿"),
      Item.new("填写单价并注明来源", :before_publish, products.any? && products.all? { |item| item["unit_price"].to_d.positive? && item["price_source"].present? && item["price_source"] != "unpriced" }, "创建草稿后可以继续填写"),
      Item.new("确认运费与来源", :before_publish, freight_complete?, "CIF、CFR、DAP、DDP 报价发布前需要"),
      Item.new("补充规格、包装和交期", :recommended, products.any? && products.all? { |item| item["specifications"].present? && item["packing"].present? && item["lead_time"].present? }, "信息越完整，客户往返确认越少"),
      Item.new("关联商品库", :optional, products.any? && products.all? { |item| item["catalog_product_id"].present? }, "一次性商品也可以直接用于本次报价")
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
