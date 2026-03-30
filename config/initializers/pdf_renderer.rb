Rails.application.configure do
  config.x.quote_pdf ||= ActiveSupport::OrderedOptions.new
  config.x.quote_pdf.engine = ENV.fetch("QUOTE_PDF_ENGINE", "grover").to_s.downcase
end
