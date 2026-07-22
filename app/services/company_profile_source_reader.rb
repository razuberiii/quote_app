class CompanyProfileSourceReader
  MAX_CHARACTERS = 40_000

  def initialize(profile_import) = @profile_import = profile_import

  def call
    [ @profile_import.source_text, attached_text ].compact_blank.join("\n\n").first(MAX_CHARACTERS)
  end

  private

  def attached_text
    return unless @profile_import.source_file.attached?

    blob = @profile_import.source_file.blob
    blob.open do |file|
      return PDF::Reader.new(file.path).pages.map(&:text).join("\n\n") if blob.content_type == "application/pdf"
      return file.read.force_encoding("UTF-8").scrub if blob.content_type.in?(%w[text/plain text/csv application/csv])
    end
    nil
  rescue PDF::Reader::MalformedPDFError, EncodingError => error
    @profile_import.warnings << I18n.t("self_service.company_import.warnings.file_unreadable", error: error.message)
    nil
  end
end
