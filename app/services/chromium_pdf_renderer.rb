require "open3"
require "tempfile"
require "tmpdir"
require "fileutils"

class ChromiumPdfRenderer
  class RenderError < StandardError; end

  def initialize(html, executable: ENV.fetch("CHROME_BIN", "/usr/bin/chromium"))
    @html = html
    @executable = executable
  end

  def render
    Tempfile.create([ "rubusoo-document", ".html" ]) do |source|
      Tempfile.create([ "rubusoo-document", ".pdf" ]) do |output|
        source.binmode
        source.write(@html)
        source.flush
        output.close

        command = [
          @executable, "--headless", "--no-sandbox", "--disable-gpu",
          "--disable-dev-shm-usage", "--disable-crash-reporter", "--disable-crashpad",
          "--noerrdialogs", "--no-pdf-header-footer",
          "--print-to-pdf=#{output.path}", "file://#{source.path}"
        ]
        runtime_home = Dir.mktmpdir("rubusoo-chromium")
        _stdout, stderr, status = Open3.capture3({ "HOME" => runtime_home, "XDG_CONFIG_HOME" => runtime_home }, *command)
        binary = File.binread(output.path) if status.success? && File.exist?(output.path)
        raise RenderError, stderr.presence || "Chromium did not produce a PDF." if binary.blank?

        binary
      ensure
        FileUtils.remove_entry(runtime_home) if runtime_home && Dir.exist?(runtime_home)
      end
    end
  rescue Errno::ENOENT => error
    raise RenderError, "Chromium executable is unavailable: #{error.message}"
  end
end
