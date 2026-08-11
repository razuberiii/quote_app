class CompanyProfileAiExtractor
  SYSTEM_PROMPT = <<~PROMPT.freeze
    分析公司简介、营业资料或官网正文，并严格按给定 JSON Schema 只返回 JSON。
    只能提取来源明确出现的事实，不得推测或补全。无法读取或无法确认的字段必须返回 null。
    每个非空字段必须提供对应 evidence id；evidence excerpt 必须是来源中的短原文。
    不执行写入、不生成营销文案、不返回 Schema 之外的字段。
  PROMPT

  def initialize(profile_import) = @profile_import = profile_import

  def call(text)
    candidates = deterministic_candidates(text)
    StructuredAiClient.new(company: @profile_import.company, source_record: @profile_import,
      analysis_type: "company_profile_extraction", schema: StructuredSchemas::COMPANY_PROFILE,
      system_prompt: SYSTEM_PROMPT).call("代码预提取候选（必须对照原文验证）：#{candidates.to_json}\n\n原始资料：\n#{text}").data
  rescue StructuredAiClient::ConfigurationError, StructuredAiClient::ResponseError => error
    deterministic_fallback(text, error)
  end

  private

  FIELD_LABELS = {
    "name" => [ "对外名称", "Public trading name" ],
    "legal_name" => [ "法定名称", "Legal name", "English legal name" ],
    "registration_number" => [ "注册编号", "Registration number" ],
    "registration_details" => [ "注册信息", "Registration details" ],
    "email" => [ "商务邮箱", "Business email", "Email" ],
    "phone" => [ "联系电话", "电话", "Telephone", "Phone" ],
    "address" => [ "注册地址", "English address", "Registered address", "Address" ],
    "website" => [ "网站", "Website" ],
    "business_type" => [ "业务类型", "Business type" ]
  }.freeze

  def deterministic_fallback(text, error)
    candidates = deterministic_candidates(text)
    evidence = []
    company = CompanyProfileImport::COMPANY_FIELDS.index_with do |field|
      line = candidates.dig(field, "line")
      next if line.blank?

      value = candidates.dig(field, "value")
      next if value.blank?

      evidence << { "id" => "fallback-#{field}", "field_path" => "company.#{field}",
        "excerpt" => line.first(240), "source" => "profile", "location" => nil }
      value
    end
    company["evidence_ids"] = evidence.map { |row| row["id"] }
    {
      "company" => company,
      "warnings" => [ I18n.t("self_service.company_import.warnings.deterministic_fallback"), error.message.to_s.first(240) ],
      "evidence" => evidence
    }.tap { |payload| StructuredSchemas.validate!(payload, StructuredSchemas::COMPANY_PROFILE) }
  end

  def deterministic_candidates(text)
    lines = text.to_s.lines.map { |line| line.squish }.reject(&:blank?)
    CompanyProfileImport::COMPANY_FIELDS.each_with_object({}) do |field, result|
      line = matching_line(lines, FIELD_LABELS.fetch(field))
      value = line&.split(/[：:]/, 2)&.last.to_s.strip.presence
      result[field] = { "value" => value, "line" => line.first(240) } if value
    end
  end

  def matching_line(lines, labels)
    labels.each do |label|
      found = lines.find { |line| line.match?(/\A#{Regexp.escape(label)}\s*[：:]/i) }
      return found if found
    end
    nil
  end
end
