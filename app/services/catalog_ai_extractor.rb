class CatalogAiExtractor
  SYSTEM_PROMPT = <<~PROMPT.freeze
    将产品目录转换为给定 JSON Schema 的候选数据，只返回 JSON。
    只能提取来源中明确存在的事实。不得猜测商品、价格、币种、交期、MOQ、包装或公司事实。
    specifications 必须使用 [{name, value}] 数组；每个非空候选必须引用 evidence id，evidence excerpt 必须来自原文，并保留页码、Sheet 或 Cell 位置。
    无法确定时使用 null，并写入 warnings。价格只有在来源明确出现时才可返回。
  PROMPT

  def initialize(batch) = @batch = batch

  def call(text)
    result = StructuredAiClient.new(company: @batch.company, source_record: @batch,
      analysis_type: "catalog_extraction", schema: StructuredSchemas::CATALOG,
      system_prompt: SYSTEM_PROMPT).call(text)
    evidence = Array(result.data["evidence"]).index_by { |item| item["id"] }
    products = Array(result.data["products"]).map do |product|
      cited = Array(product["evidence_ids"]).filter_map { |id| evidence[id] }
      variants = Array(product["variants"]).map { |variant| variant.merge("specifications" => specification_hash(variant["specifications"])) }
      product.except("evidence_ids").merge("specifications" => specification_hash(product["specifications"]),
        "variants" => variants, "evidence" => cited)
    end
    [ products, Array(result.data["warnings"]) ]
  end


  private

  def specification_hash(value)
    Array(value).each_with_object({}) do |row, normalized|
      name = row["name"].to_s.strip
      normalized[name] = row["value"] if name.present? && row["value"].present?
    end
  end
end
