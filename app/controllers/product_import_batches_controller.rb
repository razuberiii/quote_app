class ProductImportBatchesController < ApplicationController
  before_action :set_batch, only: %i[show update apply]

  def new = @batch = current_user.company.product_import_batches.new

  def create
    files = Array(params.dig(:product_import_batch, :source_files)).reject(&:blank?)
    return redirect_to new_product_import_batch_path, alert: t("self_service.catalog_import.errors.file_required") if files.empty?
    result = ProductCatalogParser.new(files).call
    @batch = current_user.company.product_import_batches.create!(created_by: current_user, input_fingerprint: result.fingerprint,
      warnings: result.warnings, processing_report: result.processing_report, status: "review")
    @batch.source_files.attach(files)
    products = result.products
    if result.ai_required && result.ai_input.present?
      begin
        ai_products, ai_warnings = CatalogAiExtractor.new(@batch).call(result.ai_input)
        products = merge_candidates(products, ai_products)
        @batch.update!(warnings: @batch.warnings + ai_warnings)
      rescue StructuredAiClient::ResponseError, StructuredAiClient::ConfigurationError => error
        failed_report = @batch.processing_report.map { |range| range["analysis"] == "ai_required" ? range.merge("status" => "failed", "detail" => t("self_service.catalog_import.errors.ai_failed_detail")) : range }
        @batch.update!(processing_report: failed_report,
          warnings: @batch.warnings + [ t("self_service.catalog_import.errors.ai_failed", error: error.message) ])
      end
    end
    products.each do |data|
      match = data["sku"].present? && current_user.company.products.find_by("LOWER(sku) = ?", data["sku"].downcase)
      @batch.product_import_candidates.create!(candidate_data: data.except("evidence"), evidence: data["evidence"], confidence: data["confidence"], matched_product: match, decision: "pending")
    end
    redirect_to @batch
  rescue CSV::MalformedCSVError => error
    @batch&.update!(status: "review", warnings: @batch.warnings + [ t("self_service.catalog_import.errors.analysis_failed", error: error.message) ])
    redirect_to(@batch || new_product_import_batch_path, alert: t("self_service.catalog_import.errors.file_retained"))
  end

  def show
    @candidates = @batch.product_import_candidates.includes(:matched_product).order(:id)
    @products = current_user.company.products.order(:name)
  end

  def update
    persist_review!
    redirect_to @batch, notice: t("self_service.catalog_import.flash.review_saved")
  end

  def apply
    persist_review!
    Product.transaction do
      @batch.product_import_candidates.where.not(decision: %w[pending ignore]).find_each { |candidate| apply_candidate(candidate) }
      @batch.update!(status: "applied")
    end
    redirect_to library_path, notice: t("self_service.catalog_import.flash.applied")
  end

  private

  def set_batch = @batch = current_user.company.product_import_batches.find(params[:id])

  def persist_review!
    params.fetch(:candidates, {}).each do |id, attrs|
      candidate = @batch.product_import_candidates.find(id)
      data = attrs.fetch(:candidate_data, {}).permit!.to_h
      candidate.update!(decision: attrs[:decision], matched_product_id: attrs[:matched_product_id],
        candidate_data: candidate.candidate_data.merge(data))
    end
  end

  def apply_candidate(candidate)
    data = candidate.candidate_data
    product = candidate.decision == "merge" ? candidate.matched_product : nil
    product ||= current_user.company.products.new
    if candidate.decision == "variant" && candidate.matched_product
      data = data.merge("description" => [ data["description"], "Variant of #{candidate.matched_product.name}" ].compact.join(" · "))
    end
    product.assign_attributes(name: data["name"], sku: data["sku"].presence, product_category: data["category"], description: data["description"], unit: data["unit"], moq: data["moq"], lead_time: data["lead_time"], price_currency: data["currency"].presence || product.price_currency || "USD", default_price: data["explicit_price"].presence || product.default_price)
    product.save!
    candidate.update!(matched_product: product)
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
