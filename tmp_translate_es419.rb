require "yaml"
require "json"
require "net/http"
require "uri"

EN_PATH = "config/locales/en.yml"
ES_PATH = "config/locales/es-419.yml"

en_root = YAML.load_file(EN_PATH).fetch("en")
es_file = YAML.load_file(ES_PATH)
es_root = es_file.fetch("es-419")

CACHE = {}

# Protect placeholders/tags from translation engine.
def protect_tokens(text)
  tokens = []
  protected_text = text.gsub(/%\{[^}]+\}|<[^>]+>|\n|\{\{[^}]+\}\}/) do |m|
    token = "__TK#{tokens.length}__"
    tokens << m
    token
  end
  [protected_text, tokens]
end

def restore_tokens(text, tokens)
  out = text.dup
  tokens.each_with_index { |t, i| out = out.gsub("__TK#{i}__", t) }
  out
end

def translate_text(text)
  return text if text.nil? || text.strip.empty?
  return CACHE[text] if CACHE.key?(text)

  protected_text, tokens = protect_tokens(text)
  q = URI.encode_www_form_component(protected_text)
  url = URI("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=es&dt=t&q=#{q}")

  translated = text
  begin
    res = Net::HTTP.get_response(url)
    if res.is_a?(Net::HTTPSuccess)
      body = JSON.parse(res.body)
      raw = body[0].map { |seg| seg[0] }.join
      translated = restore_tokens(raw, tokens)
      translated = translated.gsub("\u00A0", " ")
    end
  rescue
    translated = text
  end

  CACHE[text] = translated
  translated
end

def deep_translate!(en_node, es_node)
  case en_node
  when Hash
    en_node.each do |k, v|
      if v.is_a?(Hash)
        es_node[k] ||= {}
        deep_translate!(v, es_node[k])
      else
        # Translate only when current es value is missing or identical to english.
        current = es_node[k]
        if current.nil? || current == v
          es_node[k] = v.is_a?(String) ? translate_text(v) : v
        end
      end
    end
  end
end

deep_translate!(en_root, es_root)

File.write(ES_PATH, { "es-419" => es_root }.to_yaml(line_width: -1))
puts "translated"
