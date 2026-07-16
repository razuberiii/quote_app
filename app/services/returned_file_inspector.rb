require "csv"
require "rexml/document"
require "zip"

class ReturnedFileInspector
  Result = Data.define(:unsafe_cells, :formulas, :text)
  DANGEROUS_FORMULA = /(?:WEBSERVICE|HYPERLINK|DDE|EXEC|CMD|\[[^\]]+\]|https?:\/\/)/i

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    return Result.new([], [], "") unless @attachment&.attached?
    @attachment.open do |file|
      if @attachment.content_type == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        inspect_xlsx(file.path)
      else
        inspect_csv(file.read)
      end
    end
  rescue Zip::Error, REXML::ParseException, CSV::MalformedCSVError => error
    raise InquirySourceReader::UnreadableFile, "The returned spreadsheet could not be safely inspected: #{error.message}"
  end

  private

  def inspect_xlsx(path)
    formulas = []
    text = []
    Zip::File.open(path) do |archive|
      archive.glob("xl/worksheets/sheet*.xml").each do |entry|
        document = REXML::Document.new(entry.get_input_stream.read)
        REXML::XPath.match(document, "//*[local-name()='c']").each do |cell|
          formula = REXML::XPath.first(cell, "*[local-name()='f']")&.text
          value = REXML::XPath.first(cell, "*[local-name()='v']")&.text
          formulas << { "cell" => cell.attributes["r"], "formula" => neutralize(formula) } if formula.present?
          text << value if value.present?
        end
      end
    end
    unsafe = formulas.select { |entry| entry["formula"].match?(DANGEROUS_FORMULA) }
    Result.new(unsafe, formulas, text.first(500).join(" | "))
  end

  def inspect_csv(content)
    unsafe = []
    values = CSV.parse(content.to_s, liberal_parsing: true).flatten.compact
    values.each_with_index do |value, index|
      unsafe << { "cell" => index + 1, "formula" => neutralize(value) } if value.lstrip.match?(/\A[=+\-@]/)
    end
    Result.new(unsafe, [], values.first(500).join(" | "))
  end

  def neutralize(value)
    value.to_s.gsub(/[\r\n\t]/, " ").first(500)
  end
end
