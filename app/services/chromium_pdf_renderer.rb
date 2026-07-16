require "open3"
require "tempfile"

class ChromiumPdfRenderer
  class RenderError < StandardError; end

  def initialize(html, executable: ENV.fetch("CHROME_BIN", "/usr/bin/chromium"))
    @html = html
    @executable = executable
  end

  def render
    Tempfile.create(["rubusoo-document", ".html"]) do |source|
      Tempfile.create(["rubusoo-document", ".pdf"]) do |output|
        source.binmode
        source.write(@html)
        source.flush
        output.close

        command = [
          @executable, "--headless", "--no-sandbox", "--disable-gpu",
          "--disable-dev-shm-usage", "--no-pdf-header-footer",
          "--print-to-pdf=#{output.path}", "file://#{source.path}"
        ]
        _stdout, stderr, status = Open3.capture3(*command)
        binary = File.binread(output.path) if status.success? && File.exist?(output.path)
        raise RenderError, stderr.presence || "Chromium did not produce a PDF." if binary.blank?

        binary
      end
    end
  rescue Errno::ENOENT => error
    raise RenderError, "Chromium executable is unavailable: #{error.message}"
  end
end
