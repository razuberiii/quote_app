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
MAX_RETRIES = 4

PLACEHOLDER_PATTERN = /%\{[^}]+\}|__SHARE_URL__|<[^>]+>|\{\{[^}]+\}\}/

options = {
  en_path: DEFAULT_EN_PATH,
  es_path: DEFAULT_ES_PATH,
  output_path: DEFAULT_OUTPUT_PATH,
  cache_path: DEFAULT_CACHE_PATH,
  model: DEFAULT_MODEL,
  fallback_models: DEFAULT_FALLBACK_MODELS,
  mode: :safe,
  limit: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby script/translate_es419_with_openai.rb [options]"

  parser.on("--en PATH", "English locale file path") { |value| options[:en_path] = File.expand_path(value) }
  parser.on("--es PATH", "es-419 locale file path") { |value| options[:es_path] = File.expand_path(value) }
  parser.on("--out PATH", "Output path for translated locale file") { |value| options[:output_path] = File.expand_path(value) }
  parser.on("--cache PATH", "Translation cache path") { |value| options[:cache_path] = File.expand_path(value) }
  parser.on("--model MODEL", "Gemini model to use (default: #{DEFAULT_MODEL})") { |value| options[:model] = value }
  parser.on("--fallback-models x,y,z", Array, "Fallback Gemini models") { |value| options[:fallback_models] = value }
  parser.on("--all", "Translate every string from en.yml into es-419 output") { options[:mode] = :all }
  parser.on("--limit N", Integer, "Translate at most N strings in this run") { |value| options[:limit] = value }
end.parse!

api_key = ENV["GEMINI_API_KEY"].to_s
abort("GEMINI_API_KEY is required") if api_key.empty?

def load_locale(path)
  YAML.safe_load(File.read(path), aliases: true)
end

def ensure_parent_dir(path)
  Dir.mkdir(File.dirname(path)) unless Dir.exist?(File.dirname(path))
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
  tokens.each_with_index do |token_value, index|
    restored.gsub!("__TOKEN_#{index}__", token_value)
  end
  restored
end

def translate_text(api_key:, model:, fallback_models:, cache:, text:, key_path:)
  return text if text.to_s.strip.empty?

  models = ([ model ] + fallback_models).uniq
  cache_key = "#{models.join('|')}::#{text}"
  return cache[cache_key] if cache.key?(cache_key)

  protected_text, tokens = protect_tokens(text)
  _, translated = translate_with_gemini(
    api_key: api_key,
    models: models,
    protected_text: protected_text,
    key_path: key_path
  )
  translated = text if translated.empty?
  translated = restore_tokens(translated, tokens)
  cache[cache_key] = translated
  translated
end

def perform_gemini_request(api_key:, model:, prompt:)
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")
  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(
    generationConfig: {
      temperature: 0,
      topP: 0.95,
      maxOutputTokens: 512
    },
    contents: [
      {
        role: "user",
        parts: [ { text: prompt } ]
      }
    ]
  )

  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 120) do |http|
    http.request(request)
  end
end

def translate_with_gemini(api_key:, models:, protected_text:, key_path:)
  prompt = <<~PROMPT
    Translate software UI text from English to Latin American Spanish.
    Preserve placeholders, tokens, line breaks, punctuation, and formatting exactly.
    Return only the translated text.

    Key path: #{key_path}

    Text:
    #{protected_text}
  PROMPT

  errors = []

  models.each do |candidate_model|
    MAX_RETRIES.times do |attempt|
      response = perform_gemini_request(api_key: api_key, model: candidate_model, prompt: prompt)
      if response.is_a?(Net::HTTPSuccess)
        payload = JSON.parse(response.body)
        text = payload.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip
        return [ candidate_model, text ] unless text.empty?
        errors << "#{candidate_model}: empty response"
        break
      end

      errors << "#{candidate_model}: #{response.code} #{response.body}"
      break unless [ 429, 500, 503 ].include?(response.code.to_i)

      sleep((attempt + 1) * 2)
    end
  end

  abort("Gemini request failed: #{errors.last}")
end

def duplicate_structure(node)
  case node
  when Hash
    node.each_with_object({}) { |(key, value), copy| copy[key] = duplicate_structure(value) }
  when Array
    node.map { |value| duplicate_structure(value) }
  else
    node
  end
end

def should_translate?(mode:, english_value:, current_value:)
  return true if mode == :all
  return true if current_value.nil?
  return true if current_value == english_value

  false
end

def merge_translations!(target:, english:, current:, api_key:, model:, fallback_models:, cache:, mode:, stats:, limit:, path: [])
  return if limit && stats[:translated] >= limit

  case english
  when Hash
    target ||= {}
    english.each do |key, english_value|
      current_value = current.is_a?(Hash) ? current[key] : nil
      target[key] = merge_translations!(
        target: target[key],
        english: english_value,
        current: current_value,
        api_key: api_key,
        model: model,
        fallback_models: fallback_models,
        cache: cache,
        mode: mode,
        stats: stats,
        limit: limit,
        path: path + [ key ]
      )
      break if limit && stats[:translated] >= limit
    end
    target
  when Array
    current_array = current.is_a?(Array) ? current : []
    english.each_with_index.map do |english_value, index|
      merge_translations!(
        target: current_array[index],
        english: english_value,
        current: current_array[index],
        api_key: api_key,
        model: model,
        fallback_models: fallback_models,
        cache: cache,
        mode: mode,
        stats: stats,
        limit: limit,
        path: path + [ index ]
      )
    end
  when String
    if should_translate?(mode: mode, english_value: english, current_value: current)
      stats[:translated] += 1
      translate_text(
        api_key: api_key,
        model: model,
        fallback_models: fallback_models,
        cache: cache,
        text: english,
        key_path: path.join(".")
      )
    else
      stats[:skipped] += 1
      current
    end
  else
    current.nil? ? english : current
  end
end

en_data = load_locale(options[:en_path]).fetch("en")
es_wrapper = load_locale(options[:es_path])
current_es_data = es_wrapper.fetch("es-419")
output_es_data = duplicate_structure(current_es_data)
cache = load_cache(options[:cache_path])
stats = { translated: 0, skipped: 0 }

translated_root = merge_translations!(
  target: output_es_data,
  english: en_data,
  current: current_es_data,
  api_key: api_key,
  model: options[:model],
  fallback_models: options[:fallback_models],
  cache: cache,
  mode: options[:mode],
  stats: stats,
  limit: options[:limit]
)

ensure_parent_dir(options[:output_path])
File.write(options[:output_path], { "es-419" => translated_root }.to_yaml(line_width: -1))
save_cache(options[:cache_path], cache)

puts "Wrote #{options[:output_path]}"
puts "Translated: #{stats[:translated]}"
puts "Skipped: #{stats[:skipped]}"
