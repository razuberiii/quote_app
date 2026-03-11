require "json"
require "net/http"
require "optparse"
require "uri"
require "yaml"

DEFAULT_EN_PATH = File.expand_path("../config/locales/en.yml", __dir__)
DEFAULT_ES_PATH = File.expand_path("../config/locales/es-419.yml", __dir__)
DEFAULT_OUTPUT_PATH = File.expand_path("../tmp/es-419.gemini.yml", __dir__)
DEFAULT_CACHE_PATH = File.expand_path("../tmp/es-419.gemini-cache.json", __dir__)
DEFAULT_MODEL = ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash")
DEFAULT_FALLBACK_MODELS = ENV.fetch("GEMINI_FALLBACK_MODELS", "gemini-2.0-flash,gemini-1.5-flash").split(",").map(&:strip).reject(&:empty?)
DEFAULT_BATCH_SIZE = 25
MAX_RETRIES = 4
PLACEHOLDER_PATTERN = /%\{[^}]+\}|__SHARE_URL__|<[^>]+>|\{\{[^}]+\}\}/

options = {
  en_path: DEFAULT_EN_PATH,
  es_path: DEFAULT_ES_PATH,
  output_path: DEFAULT_OUTPUT_PATH,
  cache_path: DEFAULT_CACHE_PATH,
  model: DEFAULT_MODEL,
  fallback_models: DEFAULT_FALLBACK_MODELS,
  batch_size: DEFAULT_BATCH_SIZE,
  mode: :safe,
  limit: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/translate_es419_with_gemini_batch.rb [options]"
  parser.on("--en PATH") { |value| options[:en_path] = File.expand_path(value) }
  parser.on("--es PATH") { |value| options[:es_path] = File.expand_path(value) }
  parser.on("--out PATH") { |value| options[:output_path] = File.expand_path(value) }
  parser.on("--cache PATH") { |value| options[:cache_path] = File.expand_path(value) }
  parser.on("--model MODEL") { |value| options[:model] = value }
  parser.on("--fallback-models x,y,z", Array) { |value| options[:fallback_models] = value }
  parser.on("--batch-size N", Integer) { |value| options[:batch_size] = value }
  parser.on("--all") { options[:mode] = :all }
  parser.on("--limit N", Integer) { |value| options[:limit] = value }
end.parse!

api_key = ENV["GEMINI_API_KEY"].to_s
abort("GEMINI_API_KEY is required") if api_key.empty?

def load_yaml(path)
  YAML.safe_load(File.read(path), aliases: true)
end

def ensure_parent_dir(path)
  dir = File.dirname(path)
  Dir.mkdir(dir) unless Dir.exist?(dir)
end

def load_cache(path)
  return {} unless File.exist?(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError
  {}
end

def save_cache(path, cache)
  ensure_parent_dir(path)
  File.write(path, JSON.pretty_generate(cache))
end

def save_output(path, root)
  ensure_parent_dir(path)
  File.write(path, { "es-419" => root }.to_yaml(line_width: -1))
end

def protect_tokens(text)
  tokens = []
  protected = text.gsub(PLACEHOLDER_PATTERN) do |match|
    token = "__TOKEN_#{tokens.length}__"
    tokens << match
    token
  end
  [ protected, tokens ]
end

def restore_tokens(text, tokens)
  restored = text.to_s.dup
  tokens.each_with_index { |token, index| restored.gsub!("__TOKEN_#{index}__", token) }
  restored
end

def duplicate_structure(node)
  case node
  when Hash
    node.each_with_object({}) { |(key, value), memo| memo[key] = duplicate_structure(value) }
  when Array
    node.map { |value| duplicate_structure(value) }
  else
    node
  end
end

def should_translate?(mode:, english_value:, current_value:)
  return true if mode == :all
  return true if current_value.nil?
  current_value == english_value
end

def collect_candidates(english, current, mode:, path: [], out: [])
  case english
  when Hash
    english.each do |key, value|
      current_value = current.is_a?(Hash) ? current[key] : nil
      collect_candidates(value, current_value, mode: mode, path: path + [ key ], out: out)
    end
  when Array
    english.each_with_index do |value, index|
      current_value = current.is_a?(Array) ? current[index] : nil
      collect_candidates(value, current_value, mode: mode, path: path + [ index ], out: out)
    end
  when String
    if should_translate?(mode: mode, english_value: english, current_value: current)
      out << { path: path, text: english }
    end
  end
  out
end

def assign_path!(root, path, value)
  cursor = root
  path[0...-1].each_with_index do |segment, index|
    next_segment = path[index + 1]

    if segment.is_a?(Integer)
      cursor[segment] ||= next_segment.is_a?(Integer) ? [] : {}
      cursor = cursor[segment]
    else
      cursor[segment] ||= next_segment.is_a?(Integer) ? [] : {}
      cursor = cursor[segment]
    end
  end
  cursor[path.last] = value
end

def perform_request(api_key:, model:, body:)
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")
  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(body)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 180) do |http|
    http.request(request)
  end
end

def translate_batch(api_key:, models:, batch:)
  protected_batch = batch.map.with_index do |item, index|
    protected_text, tokens = protect_tokens(item[:text])
    item.merge(id: index.to_s, protected_text: protected_text, tokens: tokens)
  end

  payload = protected_batch.map { |item| { id: item[:id], key_path: item[:path].join("."), text: item[:protected_text] } }
  prompt = <<~PROMPT
    Translate each software UI string from English to Latin American Spanish.
    Preserve placeholders, tokens, punctuation, and line breaks exactly.
    Return strict JSON with this shape only:
    {"translations":[{"id":"0","text":"..."}]}

    Input:
    #{JSON.pretty_generate(payload)}
  PROMPT

  errors = []
  models.each do |model|
    MAX_RETRIES.times do |attempt|
      response = perform_request(
        api_key: api_key,
        model: model,
        body: {
          generationConfig: {
            temperature: 0,
            topP: 0.95,
            maxOutputTokens: 8192,
            responseMimeType: "application/json"
          },
          contents: [ { role: "user", parts: [ { text: prompt } ] } ]
        }
      )

      if response.is_a?(Net::HTTPSuccess)
        raw = JSON.parse(response.body).dig("candidates", 0, "content", "parts", 0, "text").to_s
        parsed = JSON.parse(raw)
        translations = parsed.fetch("translations")
        by_id = translations.each_with_object({}) { |row, memo| memo[row.fetch("id")] = row.fetch("text") }

        return protected_batch.map do |item|
          translated = by_id[item[:id]].to_s
          translated = item[:text] if translated.empty?
          item.merge(translated_text: restore_tokens(translated, item[:tokens]))
        end
      end

      errors << "#{model}: #{response.code} #{response.body}"
      break unless [ 429, 500, 503 ].include?(response.code.to_i)
      sleep((attempt + 1) * 2)
    rescue JSON::ParserError => error
      errors << "#{model}: invalid JSON #{error.message}"
      break
    end
  end

  abort("Gemini batch request failed: #{errors.last}")
end

en_data = load_yaml(options[:en_path]).fetch("en")
es_wrapper = load_yaml(options[:es_path])
es_data = es_wrapper.fetch("es-419")
output_root = duplicate_structure(es_data)
cache = load_cache(options[:cache_path])

candidates = collect_candidates(en_data, es_data, mode: options[:mode])
candidates = candidates.first(options[:limit]) if options[:limit]

translated_count = 0
skipped_count = 0
models = ([ options[:model] ] + options[:fallback_models]).uniq

candidates.each_slice(options[:batch_size]) do |batch|
  uncached = []

  batch.each do |item|
    cache_key = "#{models.join('|')}::#{item[:text]}"
    if cache.key?(cache_key)
      assign_path!(output_root, item[:path], cache[cache_key])
      skipped_count += 1
    else
      uncached << item.merge(cache_key: cache_key)
    end
  end

  if uncached.any?
    results = translate_batch(api_key: api_key, models: models, batch: uncached)
    results.each do |result|
      cache[result[:cache_key]] = result[:translated_text]
      assign_path!(output_root, result[:path], result[:translated_text])
      translated_count += 1
    end
    save_cache(options[:cache_path], cache)
    save_output(options[:output_path], output_root)
  end
end

save_cache(options[:cache_path], cache)
save_output(options[:output_path], output_root)

puts "Wrote #{options[:output_path]}"
puts "Translated: #{translated_count}"
puts "Cache hits: #{skipped_count}"
