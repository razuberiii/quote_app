require "csv"
require "pdf/reader"
require "rexml/document"
require "zip"

class PurchaseOrderAttachmentParser
  HEADER_ALIASES = {
    "sku" => %w[sku item_code product_code model], "description" => %w[description product item product_name],
    "specifications" => %w[specifications specification specs], "quantity" => %w[quantity qty],
    "unit" => %w[unit uom], "unit_price" => %w[unit_price price unitprice], "amount" => %w[amount line_total total]
  }.freeze

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    return {} unless @attachment&.attached?
    @attachment.open do |file|
      extension = @attachment.filename.extension.to_s.downcase
      return parse_xlsx(file.path) if extension == "xlsx"
      return parse_csv(file.read) if extension == "csv"
      return parse_pdf(file.path) if extension == "pdf"
      parse_text(file.read)
    end
  rescue Zip::Error, REXML::ParseException, CSV::MalformedCSVError, PDF::Reader::MalformedPDFError => error
    { "_parser" => "unreadable", "_error" => error.message }
  end

  private

  def parse_pdf(path)
    require "pdf/reader"
    text = PDF::Reader.new(path).pages.map(&:text).join("\n")
    parse_text(text).merge("_parser" => "pdf_text")
  end

  def parse_csv(content)
    table = CSV.parse(content.to_s, headers: true, liberal_parsing: true)
    rows = table.map { |row| row.to_h }
    from_rows(table.headers, rows.map(&:values)).merge("_parser" => "csv")
  end

  def parse_xlsx(path)
    Zip::File.open(path) do |archive|
      shared = shared_strings(archive)
      sheets = archive.glob("xl/worksheets/sheet*.xml").map { |entry| rows(entry, shared) }
      table = sheets.max_by(&:length) || []
      header_index = table.index { |row| recognized_headers(row).size >= 3 } || 0
      from_rows(table[header_index] || [], table.drop(header_index + 1)).merge("_parser" => "xlsx")
    end
  end

  def from_rows(headers, rows)
    normalized = headers.map { |value| normalize(value) }
    items = rows.filter_map do |row|
      item = HEADER_ALIASES.to_h do |field, aliases|
        index = normalized.index { |header| aliases.include?(header) }
        [ field, index ? row[index] : nil ]
      end
      item.compact_blank!
      item if item.present? && (item["sku"].present? || item["description"].present?)
    end
    text = rows.flatten.compact.join("\n")
    parse_text(text).merge("items" => items)
  end

  def parse_text(text)
    value = text.to_s
    parsed = JSON.parse(value)
    parsed.deep_stringify_keys.merge("_parser" => "structured_json") if parsed.is_a?(Hash)
  rescue JSON::ParserError
    result = {}
    patterns = {
      "po_number" => /(?:PO|purchase\s+order)(?:\s+(?:no|number|#))?\s*[:#-]?\s*([A-Z0-9._\/-]+)/i,
      "currency" => /\b(USD|EUR|GBP|CNY|JPY|AUD|CAD|SGD|HKD)\b/i,
      "incoterm" => /\b((?:EXW|FCA|FOB|CFR|CIF|CPT|CIP|DAP|DPU|DDP)(?:\s+[A-Za-z][A-Za-z .-]+)?)/i,
      "total" => /(?:grand\s+total|order\s+total|total)\s*[:=]?\s*(?:[A-Z]{3})?\s*([\d,.]+)/i,
      "shipping" => /(?:shipping|freight)\s*[:=]?\s*(?:[A-Z]{3})?\s*([\d,.]+)/i,
      "discount" => /discount\s*[:=]?\s*(?:[A-Z]{3})?\s*([\d,.]+)/i,
      "payment_terms" => /payment\s+terms?\s*[:=]\s*([^\n]+)/i,
      "delivery_terms" => /delivery\s+terms?\s*[:=]\s*([^\n]+)/i,
      "delivery_date" => /delivery\s+date\s*[:=]\s*([^\n]+)/i
    }
    patterns.each { |key, pattern| result[key] = value[pattern, 1]&.strip }
    result.compact.merge("_parser" => "key_value_text")
  end

  def recognized_headers(row)
    aliases = HEADER_ALIASES.values.flatten
    row.map { |cell| normalize(cell) }.select { |header| aliases.include?(header) }
  end

  def normalize(value)
    value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").delete_prefix("_").delete_suffix("_")
  end

  def rows(entry, shared)
    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='row']").map do |row|
      values = []
      REXML::XPath.match(row, "*[local-name()='c']").each do |cell|
        column = cell.attributes["r"].to_s[/[A-Z]+/].to_s.chars.reduce(0) { |memo, char| memo * 26 + char.ord - 64 } - 1
        next if REXML::XPath.first(cell, "*[local-name()='f']")
        raw = REXML::XPath.first(cell, "*[local-name()='v']")&.text
        values[column] = cell.attributes["t"] == "s" ? shared[raw.to_i] : raw
      end
      values
    end
  end

  def shared_strings(archive)
    entry = archive.find_entry("xl/sharedStrings.xml")
    return [] unless entry
    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='si']").map { |node| REXML::XPath.match(node, ".//*[local-name()='t']").map(&:text).join }
  end
end
