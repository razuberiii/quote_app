WickedPdf.configure do |config|
  configured_path = ENV["WKHTMLTOPDF_PATH"].presence
  default_candidates = [
    "/usr/local/bin/wkhtmltopdf",
    "/usr/bin/wkhtmltopdf",
    "C:/Program Files/wkhtmltopdf/bin/wkhtmltopdf.exe",
    "C:/Program Files (x86)/wkhtmltopdf/bin/wkhtmltopdf.exe"
  ]

  candidate_paths = []
  candidate_paths << configured_path if configured_path
  candidate_paths.concat(default_candidates)

  # Resolve from PATH (Linux/macOS + Windows).
  resolved_from_which = `which wkhtmltopdf 2>/dev/null`.to_s.strip
  candidate_paths << resolved_from_which if resolved_from_which.present?

  resolved_from_where = `where wkhtmltopdf 2>NUL`.to_s.lines.map(&:strip).reject(&:blank?)
  candidate_paths.concat(resolved_from_where) if resolved_from_where.any?

  detected_path = candidate_paths.uniq.find do |path|
    File.exist?(path) && (Gem.win_platform? || File.executable?(path))
  end
  config.exe_path = detected_path if detected_path
  config.enable_local_file_access = true
end
