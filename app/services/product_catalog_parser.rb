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
    "product" => "name", "product name" => "name", "产品" => "name", "产品名称" => "name", "商品" => "name",
    "商品名称" => "name", "名称" => "name", "item" => "name", "model" => "name", "型号" => "name",
    "sku" => "sku", "编码" => "sku", "货号" => "sku", "category" => "category", "分类" => "category",
    "description" => "description", "描述" => "description", "基本参数" => "description", "参数" => "description",
    "规格" => "description", "配置" => "description", "unit" => "unit", "单位" => "unit", "moq" => "moq",
    "price" => "explicit_price", "unit price" => "explicit_price", "单价" => "explicit_price", "价格" => "explicit_price",
    "售价" => "explicit_price", "报价" => "explicit_price", "选配参数" => "option_name", "选配" => "option_name",
    "选配价格" => "option_price", "选配单价" => "option_price",
    "currency" => "currency", "币种" => "currency", "lead time" => "lead_time", "交期" => "lead_time",
    "packing" => "packing", "包装" => "packing"
  }.freeze
  Result = Data.define(:products, :warnings, :fingerprint, :ai_input, :processing_report, :ai_required)

  def initialize(files) = @files = Array(files).reject(&:blank?)

  def call
    warnings = []; texts = []; report = []
    products = @files.flat_map { |file| parse(file, warnings, texts, report) }
    bytes = @files.map { |file| read_bytes(file) }.join
    Result.new(products:, warnings:, fingerprint: Digest::SHA256.hexdigest(bytes),
      ai_input: texts.join("\n\n").first(120_000), processing_report: report,
      ai_required: report.any? { |range| range["analysis"] == "ai_required" })
  end

  private

  def parse(file, warnings, texts, report)
    name = file.original_filename.to_s
    case File.extname(name).downcase
    when ".csv" then parse_csv(read_bytes(file), name, warnings, report)
    when ".xlsx" then parse_xlsx(file.tempfile.path, name, warnings, texts, report)
    when ".pdf" then parse_pdf(file.tempfile.path, name, warnings, texts, report)
    when ".png", ".jpg", ".jpeg", ".webp" then parse_image(file.tempfile.path, name, warnings, texts, report)
    else
      warnings << "#{name}：暂不支持此文件类型。"
      report << range(source: name, location: "文件", status: "failed", analysis: "unsupported", detail: "不支持的文件类型")
      []
    end
  rescue StandardError => error
    warnings << "#{name}：#{error.message}"; []
  end

  def parse_csv(bytes, source, warnings, report)
    table = CSV.parse(bytes.encode("UTF-8", invalid: :replace, undef: :replace), headers: true)
    products = rows_to_candidates(table.headers, table.map(&:fields), source, "CSV", warnings)
    report << range(source:, location: "CSV · 2-#{table.size + 1} 行", status: products.any? ? "recognized" : "unrecognized",
      analysis: "deterministic", detail: "识别 #{products.size} 个商品候选")
    products
  end

  def parse_xlsx(path, source, warnings, texts, report)
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
        header_index = header_row_index(rows)
        headers = header_index ? rows[header_index] : rows.first
        body_rows = header_index ? rows.drop(header_index + 1) : rows.drop(1)
        products = rows_to_candidates(headers, body_rows, source, label, warnings, start_row: (header_index || 0) + 2)
        known_template = known_headers?(headers)
        report << range(source:, location: label, status: products.any? ? "recognized" : "unrecognized",
          analysis: known_template ? "deterministic" : "ai_required",
          detail: known_template ? "标准字段识别 #{products.size} 个候选" : "未知模板，已读取 #{rows.size} 行并等待语义分析")
        products
      end
    end
  end

  def parse_pdf(path, source, warnings, texts, report)
    pages = PDF::Reader.new(path).pages.map(&:text)
    if pages.join.strip.blank?
      pages = ocr_pdf(path)
      warnings << "#{source}：扫描 PDF 已执行 OCR，所有候选都需要人工确认。"
    end
    pages.each_with_index do |text, index|
      texts << "#{source} · 第 #{index + 1} 页\n#{text}"
      report << range(source:, location: "第 #{index + 1} 页", status: text.present? ? "extracted" : "unrecognized",
        analysis: "ai_required", detail: text.present? ? "文本已读取，等待商品语义分析" : "没有识别到可读内容")
    end
    warnings << "#{source}：页面内容将通过结构化分析生成候选，不会自动入库。"
    []
  end

  def parse_image(path, source, warnings, texts, report)
    text = ocr_image(path)
    raise "图片中没有识别到可读文字" if text.blank?
    texts << "#{source} · OCR\n#{text}"
    report << range(source:, location: "整张图片", status: "extracted", analysis: "ai_required", detail: "OCR 已完成，等待商品与图片关联分析")
    warnings << "#{source}：图片 OCR 结果需要逐项核对。"
    []
  end

  def rows_to_candidates(headers, rows, source, location, warnings, start_row: 2)
    normalized = Array(headers).map { |header| header_key(header) }
    candidates = []
    rows.each_with_index do |values, index|
      row_number = start_row + index
      next if known_headers?(values)

      data = normalized.zip(values).to_h.transform_values.with_index do |value, column|
        neutralize(value, source, row_number, Array(headers)[column], warnings)
      end
      if data["name"].blank?
        merge_continuation_row(candidates.last, data)
        next
      end
      candidates << candidate(data, source, "#{location} · #{cell_range(row_number, values.length)}")
    end
    candidates
  end

  def known_headers?(headers)
    mapped = Array(headers).map { |header| HEADER_ALIASES[header.to_s.strip.downcase] }.compact
    mapped.include?("name") && (mapped & %w[sku description explicit_price option_name]).any?
  end

  def header_row_index(rows)
    rows.each_with_index.find { |row, _index| known_headers?(row) }&.last
  end

  def range(source:, location:, status:, analysis:, detail:)
    { "source" => source, "location" => location, "status" => status, "analysis" => analysis, "detail" => detail }
  end

  def candidate(data, source, location)
    candidate_data = data.slice("name", "sku", "model", "category", "description", "unit", "moq", "lead_time", "packing", "currency")
    merge_option(candidate_data, data)
    candidate_data
      .merge("specifications" => {}, "variants" => [], "image_candidates" => [],
        "explicit_price" => decimal(data["explicit_price"]), "confidence" => 0.96,
        "evidence" => [ { "source" => source, "location" => location } ])
  end

  def merge_continuation_row(candidate_data, data)
    return if candidate_data.blank?

    description = data["description"].to_s.strip
    if description.present?
      candidate_data["description"] = [ candidate_data["description"], description ].compact_blank.join("\n")
    end
    merge_option(candidate_data, data)
  end

  def merge_option(candidate_data, data)
    option = data["option_name"].to_s.strip
    return if option.blank?

    price = decimal(data["option_price"])
    suffix = price ? "：#{price}" : nil
    candidate_data["description"] = [ candidate_data["description"], "选配：#{option}#{suffix}" ].compact_blank.join("\n")
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
