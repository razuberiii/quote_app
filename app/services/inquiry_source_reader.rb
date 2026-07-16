require "open3"
require "rexml/document"
require "zip"

class InquirySourceReader
  class UnsupportedFile < StandardError; end
  class UnreadableFile < StandardError; end

  MAX_TEXT_LENGTH = 80_000

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    raise UnsupportedFile, "Choose a PDF, XLSX, XLS, CSV, or text file" unless @attachment&.attached?

    text = @attachment.open do |file|
      case @attachment.content_type
      when "application/pdf" then read_pdf(file.path)
      when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then read_xlsx(file.path)
      when "text/csv", "text/plain" then file.read
      else
        raise UnsupportedFile, "#{@attachment.filename} is not a supported inquiry file"
      end
    end
    normalized = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace).squish
    raise UnreadableFile, "No readable text was found. Paste the inquiry or enter it manually." if normalized.blank?

    normalized.first(MAX_TEXT_LENGTH)
  rescue Zip::Error, REXML::ParseException => error
    raise UnreadableFile, "The spreadsheet could not be read: #{error.message}"
  end

  private

  def read_pdf(path)
    output, error, status = Open3.capture3("pdftotext", "-layout", path, "-")
    raise UnreadableFile, error.presence || "The PDF could not be read" unless status.success?
    output
  rescue Errno::ENOENT
    raise UnreadableFile, "PDF text extraction is unavailable"
  end

  def read_xlsx(path)
    Zip::File.open(path) do |archive|
      shared = read_shared_strings(archive)
      archive.glob("xl/worksheets/sheet*.xml").sort_by(&:name).flat_map do |entry|
        document = REXML::Document.new(entry.get_input_stream.read)
        REXML::XPath.match(document, "//*[local-name()='row']").map do |row|
          REXML::XPath.match(row, "*[local-name()='c']").filter_map do |cell|
            value = REXML::XPath.first(cell, "*[local-name()='v']")&.text
            next if value.blank?
            cell.attributes["t"] == "s" ? shared[value.to_i] : value
          end.join(" | ")
        end
      end.join("\n")
    end
  end

  def read_shared_strings(archive)
    entry = archive.find_entry("xl/sharedStrings.xml")
    return [] unless entry
    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='si']").map do |node|
      REXML::XPath.match(node, ".//*[local-name()='t']").map(&:text).join
    end
  end
end
