class InquiryAiExtractor
  ConfigurationError = StructuredAiClient::ConfigurationError
  ResponseError = StructuredAiClient::ResponseError

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Extract an export-sales inquiry into the supplied JSON Schema. Return JSON only.
    Never infer or estimate price, freight, tax, insurance, exchange rate, duty, lead
    time, company facts, or product identity. Use null for unknown values. Every
    non-null candidate must cite an evidence id whose excerpt is copied from the
    source. confidence describes extraction certainty, not commercial validity.
  PROMPT

  def initialize(inquiry: nil, **client_options)
    @inquiry = inquiry
    @client_options = client_options
  end

  def extract(source_text:, source_type:, inquiry: @inquiry)
    raise ArgumentError, "Inquiry record is required for an auditable AI call" unless inquiry
    deterministic = InquiryDeterministicParser.new(source_text).call
    result = StructuredAiClient.new(company: inquiry.company, source_record: inquiry,
      analysis_type: "inquiry_extraction", schema: StructuredSchemas::INQUIRY,
      system_prompt: SYSTEM_PROMPT, **@client_options).call("Source type: #{source_type}\nDeterministic candidates (verify against source): #{deterministic.to_json}\n\n#{source_text}")
    persist_evidence(result.data, result.analysis, inquiry)
    normalize(result.data)
  end

  private

  def persist_evidence(data, analysis, inquiry)
    Array(data["evidence"]).each do |item|
      inquiry.company.evidence_records.find_or_create_by!(source_record: inquiry, evidence_key: item["id"]) do |record|
        record.ai_analysis = analysis; record.field_path = item["field_path"]
        record.excerpt = item["excerpt"]; record.locator = { "source" => item["source"], "location" => item["location"] }
      end
    end
  end

  def normalize(data)
    evidence_by_id = Array(data["evidence"]).index_by { |item| item["id"] }
    products = Array(data["products"]).map do |product|
      evidence = Array(product["evidence_ids"]).filter_map { |id| evidence_by_id[id]&.dig("excerpt") }.join(" · ")
      product.slice("name", "model", "quantity", "unit", "specifications", "packing", "lead_time", "confidence", "evidence_ids")
        .merge("evidence" => evidence.presence, "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil)
    end
    field_evidence = Array(data["evidence"]).each_with_object({}) do |item, result|
      key = item["field_path"].to_s.split(".").last
      result[key] ||= item["excerpt"]
    end
    {
      "customer" => data["customer"], "country" => data["country"],
      "contact_name" => data.dig("contact", "name"), "contact_email" => data.dig("contact", "email"),
      "currency" => data["currency"]&.upcase, "products" => products,
      "commercial_terms" => data["commercial_terms"], "questions" => [],
      "missing_information" => data["missing_fields"], "ambiguities" => data["ambiguities"],
      "warnings" => data["warnings"], "evidence" => field_evidence,
      "evidence_records" => data["evidence"]
    }
  end
end
