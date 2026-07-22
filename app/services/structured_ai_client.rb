require "digest"
require "net/http"

class StructuredAiClient
  class ConfigurationError < StandardError; end
  class ResponseError < StandardError; end

  Result = Data.define(:data, :analysis)

  def initialize(company:, source_record:, analysis_type:, schema:, system_prompt:,
    api_key: ENV["OPENAI_API_KEY"], base_url: ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1"),
    model: ENV.fetch("OPENAI_MODEL", "gpt-5.6-luna"), http_client: Net::HTTP)
    @company = company; @source_record = source_record; @analysis_type = analysis_type
    @schema = schema; @system_prompt = system_prompt; @api_key = api_key.to_s
    @base_url = base_url.to_s.delete_suffix("/"); @model = model; @http_client = http_client
  end

  def call(input)
    raise ConfigurationError, "Structured AI analysis is not configured" if @api_key.blank?
    fingerprint = Digest::SHA256.hexdigest(input.to_s)
    cached = @company.ai_analyses.find_by(analysis_type: @analysis_type, input_fingerprint: fingerprint, status: "validated")
    return Result.new(cached.raw_json, cached) if cached

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    uri = URI("#{@base_url}/chat/completions")
    request = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json")
    request.body = {
      model: @model,
      messages: [ { role: "system", content: @system_prompt }, { role: "user", content: input.to_s } ],
      response_format: { type: "json_schema", json_schema: { name: @analysis_type, strict: true, schema: @schema } },
      max_completion_tokens: 2_500
    }.to_json
    response = @http_client.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 8, read_timeout: 60) { |http| http.request(request) }
    body = JSON.parse(response.body)
    raise ResponseError, body.dig("error", "message").presence || "AI provider returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    content = body.dig("choices", 0, "message", "content").to_s
    if content.blank?
      error = ResponseError.new("AI provider returned HTTP #{response.code} without message content")
      record_failure(fingerprint, started, error)
      raise error
    end
    data = JSON.parse(content)
    StructuredSchemas.validate!(data, @schema)
    usage = body["usage"] || {}
    analysis = @company.ai_analyses.create!(source_record: @source_record, analysis_type: @analysis_type,
      provider: URI(@base_url).host, model: @model, schema_version: StructuredSchemas::VERSION,
      input_fingerprint: fingerprint, latency_ms: elapsed_ms(started), input_tokens: usage["prompt_tokens"],
      output_tokens: usage["completion_tokens"], raw_json: data,
      validation_result: { "valid" => true }, status: "validated")
    Result.new(data, analysis)
  rescue JSON::ParserError, ArgumentError => error
    record_failure(fingerprint, started, error) if defined?(fingerprint)
    raise ResponseError, "AI returned data that failed the JSON Schema: #{error.message}"
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED => error
    record_failure(fingerprint, started, error) if defined?(fingerprint)
    raise ResponseError, "AI provider is unavailable: #{error.class}"
  end

  private

  def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000).round

  def record_failure(fingerprint, started, error)
    @company.ai_analyses.create!(source_record: @source_record, analysis_type: @analysis_type,
      provider: URI(@base_url).host, model: @model, schema_version: StructuredSchemas::VERSION,
      input_fingerprint: fingerprint, latency_ms: elapsed_ms(started), raw_json: {},
      validation_result: { "valid" => false, "error" => error.message.to_s.first(1_000) }, status: "invalid")
  rescue StandardError
    nil
  end
end
