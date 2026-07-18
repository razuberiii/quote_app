require "csv"
require "digest"
require "pdf-reader"

class ProductCatalogParser
  DANGEROUS_PREFIX = /\A[=+\-@]/
  HEADER_ALIASES = {
    "product" => "name", "product name" => "name", "item" => "name",
    "sku" => "sku", "model" => "model", "category" => "category",
    "description" => "description", "unit" => "unit", "moq" => "moq",
    "price" => "explicit_price", "unit price" => "explicit_price",
    "currency" => "currency", "lead time" => "lead_time", "packing" => "packing"
  }.freeze

  Result = Data.define(:products, :warnings, :fingerprint)

  def initialize(files)
    @files = Array(files).reject(&:blank?)
  end

  def call
    warnings = []
    products = @files.flat_map { |file| parse(file, warnings) }
    bytes = @files.map { |file| read_bytes(file) }.join
    Result.new(products:, warnings:, fingerprint: Digest::SHA256.hexdigest(bytes))
  end

  private

  def parse(file, warnings)
    name = file.original_filename.to_s
    case File.extname(name).downcase
    when ".csv" then parse_csv(read_bytes(file), name, warnings)
    when ".pdf" then parse_pdf(file, name, warnings)
    else
      warnings << "#{name}: deterministic parsing is unavailable; AI review is required."
      []
    end
  rescue StandardError => error
    warnings << "#{name}: #{error.message}"
    []
  end

  def parse_csv(bytes, source, warnings)
    table = CSV.parse(bytes.encode("UTF-8", invalid: :replace, undef: :replace), headers: true)
    table.filter_map.with_index(2) do |row, row_number|
      data = row.to_h.each_with_object({}) do |(header, value), memo|
        key = HEADER_ALIASES[header.to_s.strip.downcase] || header.to_s.strip.downcase.gsub(/\W+/, "_")
        memo[key] = neutralize(value, source, row_number, header, warnings)
      end
      next if data["name"].blank?
      candidate(data, source, "row #{row_number}")
    end
  end

  def parse_pdf(file, source, warnings)
    reader = PDF::Reader.new(file.tempfile.path)
    text = reader.pages.map(&:text).join("\n")
    warnings << "#{source}: PDF text was preserved for review; no products were created automatically."
    []
  end

  def candidate(data, source, location)
    price = decimal(data["explicit_price"])
    data.slice("name", "sku", "model", "category", "description", "unit", "moq", "lead_time", "packing", "currency")
      .merge("explicit_price" => price, "confidence" => 0.92,
             "evidence" => [ { "source" => source, "location" => location } ])
  end

  def neutralize(value, source, row, column, warnings)
    text = value.to_s.strip
    if text.match?(DANGEROUS_PREFIX)
      warnings << "#{source} row #{row}, #{column}: formula-like content was neutralized."
      return "'#{text}"
    end
    text
  end

  def decimal(value)
    BigDecimal(value.to_s.gsub(/[^\d.\-]/, "")).to_f
  rescue ArgumentError
    nil
  end

  def read_bytes(file)
    io = file.respond_to?(:tempfile) ? file.tempfile : file
    io.rewind
    io.read
  ensure
    io.rewind if io.respond_to?(:rewind)
  end
end
