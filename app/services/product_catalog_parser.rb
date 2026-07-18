require "csv"
require "digest"
require "open3"
require "pdf-reader"
require "rexml/document"
require "tmpdir"
require "zip"

class ProductCatalogParser
  DANGEROUS_PREFIX = /\A[=+\-@]/
  HEADER_ALIASES = {
    "product" => "name", "product name" => "name", "产品" => "name", "产品名称" => "name", "item" => "name",
    "sku" => "sku", "model" => "model", "型号" => "model", "category" => "category", "分类" => "category",
    "description" => "description", "描述" => "description", "unit" => "unit", "单位" => "unit", "moq" => "moq",
    "price" => "explicit_price", "unit price" => "explicit_price", "单价" => "explicit_price",
    "currency" => "currency", "币种" => "currency", "lead time" => "lead_time", "交期" => "lead_time",
    "packing" => "packing", "包装" => "packing"
  }.freeze
  Result = Data.define(:products, :warnings, :fingerprint, :ai_input)

  def initialize(files) = @files = Array(files).reject(&:blank?)

  def call
    warnings = []; texts = []
    products = @files.flat_map { |file| parse(file, warnings, texts) }
    bytes = @files.map { |file| read_bytes(file) }.join
    Result.new(products:, warnings:, fingerprint: Digest::SHA256.hexdigest(bytes), ai_input: texts.join("\n\n").first(120_000))
  end

  private

  def parse(file, warnings, texts)
    name = file.original_filename.to_s
    case File.extname(name).downcase
    when ".csv" then parse_csv(read_bytes(file), name, warnings)
    when ".xlsx" then parse_xlsx(file.tempfile.path, name, warnings, texts)
    when ".pdf" then parse_pdf(file.tempfile.path, name, warnings, texts)
    when ".png", ".jpg", ".jpeg", ".webp" then parse_image(file.tempfile.path, name, warnings, texts)
    else warnings << "#{name}：暂不支持此文件类型。"; []
    end
  rescue StandardError => error
    warnings << "#{name}：#{error.message}"; []
  end

  def parse_csv(bytes, source, warnings)
    table = CSV.parse(bytes.encode("UTF-8", invalid: :replace, undef: :replace), headers: true)
    rows_to_candidates(table.headers, table.map(&:fields), source, "CSV", warnings)
  end

  def parse_xlsx(path, source, warnings, texts)
    Zip::File.open(path) do |archive|
      shared = shared_strings(archive)
      archive.glob("xl/worksheets/sheet*.xml").sort_by(&:name).flat_map.with_index(1) do |entry, sheet_index|
        document = REXML::Document.new(entry.get_input_stream.read)
        rows = REXML::XPath.match(document, "//*[local-name()='row']").map do |row|
          cells = REXML::XPath.match(row, "*[local-name()='c']")
          values = []
          cells.each do |cell|
            column = column_index(cell.attributes["r"])
            raw = REXML::XPath.first(cell, "*[local-name()='v']")&.text
            value = case cell.attributes["t"]
            when "s" then shared[raw.to_i]
            when "inlineStr" then REXML::XPath.match(cell, ".//*[local-name()='t']").map(&:text).join
            else raw
            end
            values[column] = value
          end
          values
        end
        next [] if rows.empty?
        label = "Sheet #{sheet_index}"
        texts << "#{source} #{label}\n#{rows.map { |row| row.join(" | ") }.join("\n")}"
        rows_to_candidates(rows.first, rows.drop(1), source, label, warnings)
      end
    end
  end

  def parse_pdf(path, source, warnings, texts)
    pages = PDF::Reader.new(path).pages.map(&:text)
    if pages.join.strip.blank?
      pages = ocr_pdf(path)
      warnings << "#{source}：扫描 PDF 已执行 OCR，所有候选都需要人工确认。"
    end
    pages.each_with_index { |text, index| texts << "#{source} · 第 #{index + 1} 页\n#{text}" }
    warnings << "#{source}：页面内容将通过结构化分析生成候选，不会自动入库。"
    []
  end

  def parse_image(path, source, warnings, texts)
    text = ocr_image(path)
    raise "图片中没有识别到可读文字" if text.blank?
    texts << "#{source} · OCR\n#{text}"
    warnings << "#{source}：图片 OCR 结果需要逐项核对。"
    []
  end

  def rows_to_candidates(headers, rows, source, location, warnings)
    normalized = Array(headers).map { |header| header_key(header) }
    rows.filter_map.with_index(2) do |values, row_number|
      data = normalized.zip(values).to_h.transform_values.with_index do |value, column|
        neutralize(value, source, row_number, Array(headers)[column], warnings)
      end
      next if data["name"].blank?
      candidate(data, source, "#{location} · #{cell_range(row_number, values.length)}")
    end
  end

  def candidate(data, source, location)
    data.slice("name", "sku", "model", "category", "description", "unit", "moq", "lead_time", "packing", "currency")
      .merge("specifications" => {}, "variants" => [], "image_candidates" => [],
        "explicit_price" => decimal(data["explicit_price"]), "confidence" => 0.96,
        "evidence" => [ { "source" => source, "location" => location } ])
  end

  def header_key(header) = HEADER_ALIASES[header.to_s.strip.downcase] || header.to_s.strip.downcase.gsub(/\W+/, "_")
  def cell_range(row, count) = "A#{row}:#{column_name([ count, 1 ].max)}#{row}"
  def column_name(number) = number <= 26 ? (64 + number).chr : "Z"

  def column_index(reference)
    reference.to_s[/\A[A-Z]+/].to_s.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
  end

  def neutralize(value, source, row, column, warnings)
    text = value.to_s.strip
    if text.match?(DANGEROUS_PREFIX)
      warnings << "#{source} · #{column}#{row}：疑似公式内容已中和，未执行。"
      return "'#{text}"
    end
    text
  end

  def decimal(value)
    return if value.blank?
    BigDecimal(value.to_s.gsub(/[^\d.\-]/, "")).to_f
  rescue ArgumentError
    nil
  end

  def shared_strings(archive)
    entry = archive.find_entry("xl/sharedStrings.xml"); return [] unless entry
    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='si']").map { |node| REXML::XPath.match(node, ".//*[local-name()='t']").map(&:text).join }
  end

  def ocr_pdf(path)
    require "vips"

    Dir.mktmpdir("rubusoo-catalog") do |dir|
      image = Vips::Image.new_from_file(path, dpi: 160, access: :sequential)
      page_height = image.get("page-height")
      pages = image.get("n-pages")
      Array.new(pages) do |index|
        output = File.join(dir, "page-#{index + 1}.png")
        image.crop(0, index * page_height, image.width, page_height).write_to_file(output)
        ocr_image(output)
      end
    end
  rescue Vips::Error => error
    raise "扫描 PDF 无法转换：#{error.message}"
  end

  def ocr_image(path)
    output, error, status = Open3.capture3("tesseract", path, "stdout", "-l", "eng+chi_sim")
    raise(error.presence || "OCR 服务不可用") unless status.success?
    output
  rescue Errno::ENOENT
    raise "OCR 服务尚未安装"
  end

  def read_bytes(file)
    io = file.respond_to?(:tempfile) ? file.tempfile : file; io.rewind; io.read
  ensure
    io.rewind if io.respond_to?(:rewind)
  end
end
