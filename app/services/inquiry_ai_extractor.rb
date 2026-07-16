require "net/http"

class InquiryAiExtractor
  class ConfigurationError < StandardError; end
  class ResponseError < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract B2B export-sales inquiries into structured data. Never invent prices,
    freight, product identifiers, or buyer details. Preserve the source language in
    free-text values. Return JSON only with this exact top-level shape:
    Each extracted value that is present must include a short verbatim source excerpt
    in the evidence object. Use null rather than guessing. The exact top-level shape is:
    {
      "customer": string|null, "country": string|null,
      "contact_name": string|null,
      "contact_email": string|null,
      "currency": string|null,
      "products": [{"name": string, "model": string|null, "quantity": number|null, "unit": string|null,
                    "specifications": {"voltage": string|null, "color": string|null, "material": string|null},
                    "packing": string|null, "notes": string|null, "evidence": string}],
      "commercial_terms": {"incoterm": string|null, "destination": string|null,
                           "payment": string|null, "delivery": string|null, "packing": string|null},
      "questions": [string], "missing_information": [string],
      "evidence": {"customer": string|null, "contact_name": string|null, "contact_email": string|null,
                   "country": string|null, "currency": string|null, "destination": string|null,
                   "incoterm": string|null, "delivery": string|null, "packing": string|null}
    }
    Add concise questions for information needed to prepare a reliable quotation.
  PROMPT

  def initialize(api_key: ENV["OPENAI_API_KEY"], base_url: ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1"),
    model: ENV.fetch("OPENAI_MODEL", "gpt-5.5"), http_client: Net::HTTP)
    @api_key = api_key.to_s
    @base_url = base_url.to_s.delete_suffix("/")
    @model = model
    @http_client = http_client
  end

  def extract(source_text:, source_type:)
    raise ConfigurationError, "AI inquiry extraction is not configured" if @api_key.blank?

    uri = URI("#{@base_url}/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: "Source type: #{source_type}\n\n#{source_text}" }
      ],
      max_completion_tokens: 1_500
    }.to_json

    response = @http_client.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 8, read_timeout: 45) do |http|
      http.request(request)
    end
    body = JSON.parse(response.body)
    raise ResponseError, body.dig("error", "message").presence || "AI provider returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    content = body.dig("choices", 0, "message", "content").to_s.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
    normalize(JSON.parse(content))
  rescue JSON::ParserError => error
    raise ResponseError, "AI provider returned invalid JSON: #{error.message}"
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED => error
    raise ResponseError, "AI provider is unavailable: #{error.class}"
  end

  private

  def normalize(data)
    products = Array(data["products"]).filter_map do |product|
      next unless product.is_a?(Hash) && product["name"].present?

      {
        "name" => product["name"].to_s,
        "model" => product["model"].presence,
        "quantity" => product["quantity"],
        "unit" => product["unit"].presence,
        "specifications" => product["specifications"].is_a?(Hash) ? product["specifications"].compact_blank : {},
        "packing" => product["packing"].presence,
        "notes" => product["notes"].presence,
        "evidence" => product["evidence"].presence,
        "catalog_product_id" => nil, "unit_price" => nil, "price_source" => nil
      }
    end

    {
      "customer" => data["customer"].presence,
      "country" => data["country"].presence,
      "contact_name" => data["contact_name"].presence,
      "contact_email" => data["contact_email"].presence,
      "currency" => data["currency"].presence&.upcase,
      "products" => products,
      "commercial_terms" => data["commercial_terms"].is_a?(Hash) ? data["commercial_terms"] : {},
      "questions" => Array(data["questions"]).filter_map(&:presence),
      "missing_information" => Array(data["missing_information"]).filter_map(&:presence),
      "evidence" => data["evidence"].is_a?(Hash) ? data["evidence"] : {}
    }
  end
end
