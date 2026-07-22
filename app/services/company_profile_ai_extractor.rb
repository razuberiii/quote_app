class CompanyProfileAiExtractor
  SYSTEM_PROMPT = <<~PROMPT.freeze
    分析公司简介、营业资料或官网正文，并严格按给定 JSON Schema 只返回 JSON。
    只能提取来源明确出现的事实，不得推测或补全。无法读取或无法确认的字段必须返回 null。
    每个非空字段必须提供对应 evidence id；evidence excerpt 必须是来源中的短原文。
    不执行写入、不生成营销文案、不返回 Schema 之外的字段。
  PROMPT

  def initialize(profile_import) = @profile_import = profile_import

  def call(text)
    StructuredAiClient.new(company: @profile_import.company, source_record: @profile_import,
      analysis_type: "company_profile_extraction", schema: StructuredSchemas::COMPANY_PROFILE,
      system_prompt: SYSTEM_PROMPT).call(text).data
  end
end
