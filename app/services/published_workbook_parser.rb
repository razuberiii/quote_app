require "rexml/document"
require "zip"

class PublishedWorkbookParser
  Result = Data.define(:metadata, :items, :commercial, :unsafe_cells)

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    @attachment.open { |file| parse(file.path) }
  end

  private

  def parse(path)
    Zip::File.open(path) do |archive|
      shared = shared_strings(archive)
      sheets = archive.glob("xl/worksheets/sheet*.xml").map { |entry| rows(entry, shared) }
      quote_rows = sheets.find { |data| data.dig(0, 0) == "Rubusoo Published Version" } || []
      metadata_rows = sheets.find { |data| data.any? { |row| row[0] == "version_id" } } || []
      metadata = metadata_rows.to_h { |row| [ row[0].to_s, row[1] ] }
      header_index = quote_rows.index { |row| %w[Item Line_ID].include?(row[0]) }
      commercial_labels = [ "Shipping amount", "Discount amount", "Tax amount", "Total", "Incoterm", "Payment terms", "Delivery terms" ]
      item_rows = if header_index
        quote_rows.drop(header_index + 1).take_while { |row| row[0].present? && commercial_labels.exclude?(row[0].to_s) }
      else
        []
      end
      items = item_rows.map do |row|
        { "line_id" => row[0].to_s, "row" => row[0].to_s, "sku" => row[1].to_s, "description" => row[2].to_s,
          "specifications" => row[3].to_s, "quantity" => row[4].to_d, "unit" => row[5].to_s,
          "unit_price" => row[6].to_d, "discount" => row[7].to_d, "amount" => row[8].to_d }
      end
      commercial = quote_rows.filter_map do |row|
        label = row[0].to_s.sub(/ amount\z/, "")
        [ label, row[1] ] if %w[Shipping Discount Tax Total Incoterm Payment\ terms Delivery\ terms].include?(label)
      end.to_h
      unsafe = @unsafe_cells || []
      Result.new(metadata, items, commercial, unsafe)
    end
  end

  def rows(entry, shared)
    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='row']").map do |row|
      values = []
      REXML::XPath.match(row, "*[local-name()='c']").each do |cell|
        reference = cell.attributes["r"].to_s
        column = reference[/[A-Z]+/].to_s.chars.reduce(0) { |memo, char| memo * 26 + char.ord - 64 } - 1
        formula = REXML::XPath.first(cell, "*[local-name()='f']")&.text
        if formula.present?
          neutralized = "'#{formula.to_s.gsub(/[\r\n\t]/, ' ').first(500)}"
          (@unsafe_cells ||= []) << { "cell" => reference, "formula" => formula.to_s.gsub(/[\r\n\t]/, " ").first(500), "neutralized" => neutralized }
          values[column] = nil
          next
        end
        raw = REXML::XPath.first(cell, "*[local-name()='v']")&.text
        values[column] = if cell.attributes["t"] == "s"
          shared[raw.to_i]
        elsif cell.attributes["t"] == "inlineStr"
          REXML::XPath.match(cell, ".//*[local-name()='t']").map(&:text).join
        else
          raw
        end
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
