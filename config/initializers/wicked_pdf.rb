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

  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |path|
    next if path.blank?

    candidate_paths << File.join(path, "wkhtmltopdf")
    candidate_paths << File.join(path, "wkhtmltopdf.exe")
  end

  detected_path = candidate_paths.uniq.find do |path|
    File.exist?(path) && (Gem.win_platform? || File.executable?(path))
  end
  config.exe_path = detected_path if detected_path
  config.enable_local_file_access = true
end
