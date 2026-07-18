class ProductImportBatchesController < ApplicationController
  before_action :set_batch, only: %i[show update apply]

  def new = @batch = current_user.company.product_import_batches.new

  def create
    files = Array(params.dig(:product_import_batch, :source_files)).reject(&:blank?)
    return redirect_to new_product_import_batch_path, alert: "请选择 CSV、XLSX、PDF、扫描件或产品图片。" if files.empty?
    result = ProductCatalogParser.new(files).call
    @batch = current_user.company.product_import_batches.create!(created_by: current_user, input_fingerprint: result.fingerprint, warnings: result.warnings, status: "review")
    @batch.source_files.attach(files)
    products = result.products
    if products.empty? && result.ai_input.present?
      ai_products, ai_warnings = CatalogAiExtractor.new(@batch).call(result.ai_input)
      products = ai_products
      @batch.update!(warnings: @batch.warnings + ai_warnings)
    end
    products.each do |data|
      match = data["sku"].present? && current_user.company.products.find_by("LOWER(sku) = ?", data["sku"].downcase)
      @batch.product_import_candidates.create!(candidate_data: data.except("evidence"), evidence: data["evidence"], confidence: data["confidence"], matched_product: match, decision: match ? "merge" : "create")
    end
    redirect_to @batch
  rescue CSV::MalformedCSVError, StructuredAiClient::ResponseError, StructuredAiClient::ConfigurationError => error
    @batch&.update!(status: "review", warnings: @batch.warnings + [ "结构化分析未完成：#{error.message}" ])
    redirect_to(@batch || new_product_import_batch_path, alert: "文件已保留，但自动分析未完成。请人工审核或重试。")
  end

  def show
    @candidates = @batch.product_import_candidates.includes(:matched_product).order(:id)
    @products = current_user.company.products.order(:name)
  end

  def update
    persist_review!
    redirect_to @batch, notice: "审核结果已保存，尚未写入 Library。"
  end

  def apply
    persist_review!
    Product.transaction do
      @batch.product_import_candidates.where.not(decision: %w[pending ignore]).find_each { |candidate| apply_candidate(candidate) }
      @batch.update!(status: "applied")
    end
    redirect_to library_path, notice: "已应用审核通过的商品；来源未明确的价格仍保持为空。"
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
    product.assign_attributes(name: data["name"], sku: data["sku"].presence, product_category: data["category"], description: data["description"], unit: data["unit"], moq: data["moq"], lead_time: data["lead_time"], price_currency: data["currency"].presence || "USD", default_price: data["explicit_price"].presence || product.default_price || 0)
    product.save!
    candidate.update!(matched_product: product)
  end
end
