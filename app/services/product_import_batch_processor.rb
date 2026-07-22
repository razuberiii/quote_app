class ProductImportBatchProcessor
  SourceFile = Data.define(:tempfile, :original_filename)

  def initialize(batch) = @batch = batch

  def call
    locale = @batch.created_by&.language.presence || I18n.default_locale
    I18n.with_locale(locale) do
      with_source_files(@batch.source_files.to_a) do |files|
        result = ProductCatalogParser.new(files).call
        @batch.update!(input_fingerprint: result.fingerprint, warnings: result.warnings,
          processing_report: result.processing_report)
        products = extract_semantic_candidates(result, result.products)
        create_candidates(products)
        @batch.update!(status: "review")
      end
    end
  rescue StandardError => error
    Rails.logger.error("Product import batch #{@batch.id} failed: #{error.class}: #{error.message}")
    @batch.update!(status: "failed", warnings: Array(@batch.warnings) + [
      I18n.t("self_service.catalog_import.errors.analysis_failed", error: error.message)
    ])
  end

  private

  def with_source_files(attachments, files = [], &block)
    attachment = attachments.first
    return yield(files) unless attachment

    attachment.blob.open do |tempfile|
      source = SourceFile.new(tempfile:, original_filename: attachment.filename.to_s)
      with_source_files(attachments.drop(1), files + [ source ], &block)
    end
  end

  def extract_semantic_candidates(result, products)
    return products unless result.ai_required && result.ai_input.present?

    ai_products, ai_warnings = extract_with_retry(result.ai_input)
    @batch.update!(warnings: @batch.warnings + ai_warnings)
    merge_candidates(products, ai_products)
  rescue StructuredAiClient::ResponseError, StructuredAiClient::ConfigurationError => error
    failed_report = @batch.processing_report.map do |range|
      range["analysis"] == "ai_required" ? range.merge("status" => "failed", "detail" => I18n.t("self_service.catalog_import.errors.ai_failed_detail")) : range
    end
    @batch.update!(processing_report: failed_report, warnings: @batch.warnings + [
      I18n.t("self_service.catalog_import.errors.ai_failed", error: error.message)
    ])
    products
  end

  def extract_with_retry(input)
    attempts = 0
    begin
      attempts += 1
      CatalogAiExtractor.new(@batch).call(input)
    rescue StructuredAiClient::ResponseError => error
      retry if attempts < 2 && error.message.match?(/timeout|timed out/i)
      raise
    end
  end

  def create_candidates(products)
    products.each do |data|
      match = data["sku"].present? && @batch.company.products.find_by("LOWER(sku) = ?", data["sku"].downcase)
      @batch.product_import_candidates.create!(candidate_data: data.except("evidence"), evidence: data["evidence"],
        confidence: data["confidence"], matched_product: match, decision: "pending")
    end
  end

  def merge_candidates(deterministic, semantic)
    (deterministic + semantic).each_with_object([]) do |candidate, merged|
      key = candidate["sku"].presence&.downcase || [ candidate["name"].to_s.downcase, candidate["model"].to_s.downcase ]
      existing = merged.find { |item| (item["sku"].presence&.downcase || [ item["name"].to_s.downcase, item["model"].to_s.downcase ]) == key }
      if existing
        candidate.each { |field, value| existing[field] = value if existing[field].blank? && value.present? }
        existing["evidence"] = (Array(existing["evidence"]) + Array(candidate["evidence"])).uniq
        existing["confidence"] = [ existing["confidence"].to_f, candidate["confidence"].to_f ].max
      else
        merged << candidate.deep_dup
      end
    end
  end
end
