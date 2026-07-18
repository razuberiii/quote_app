class ProductImportBatchesController < ApplicationController
  before_action :set_batch, only: %i[show update apply]

  def new = @batch = current_user.company.product_import_batches.new

  def create
    files = Array(params.dig(:product_import_batch, :source_files)).reject(&:blank?)
    return redirect_to new_product_import_batch_path, alert: "Choose a CSV or PDF to review." if files.empty?
    result = ProductCatalogParser.new(files).call
    @batch = current_user.company.product_import_batches.create!(created_by: current_user, input_fingerprint: result.fingerprint, warnings: result.warnings, status: "review")
    @batch.source_files.attach(files)
    result.products.each do |data|
      match = data["sku"].present? && current_user.company.products.find_by("LOWER(sku) = ?", data["sku"].downcase)
      @batch.product_import_candidates.create!(candidate_data: data.except("evidence"), evidence: data["evidence"], confidence: data["confidence"], matched_product: match, decision: match ? "merge" : "create")
    end
    redirect_to @batch
  rescue CSV::MalformedCSVError => error
    redirect_to new_product_import_batch_path, alert: "The CSV could not be read: #{error.message}"
  end

  def show
    @candidates = @batch.product_import_candidates.includes(:matched_product).order(:id)
    @products = current_user.company.products.order(:name)
  end

  def update
    params.fetch(:candidates, {}).each { |id, attrs| @batch.product_import_candidates.find(id).update!(attrs.permit(:decision, :matched_product_id)) }
    redirect_to @batch, notice: "Review decisions saved."
  end

  def apply
    Product.transaction do
      @batch.product_import_candidates.where.not(decision: %w[pending ignore]).find_each { |candidate| apply_candidate(candidate) }
      @batch.update!(status: "applied")
    end
    redirect_to library_path, notice: "Approved products added. Unstated prices remain required before publishing."
  end

  private

  def set_batch = @batch = current_user.company.product_import_batches.find(params[:id])

  def apply_candidate(candidate)
    data = candidate.candidate_data
    product = candidate.decision == "merge" ? candidate.matched_product : nil
    product ||= current_user.company.products.new
    product.assign_attributes(name: data["name"], sku: data["sku"].presence, product_category: data["category"], description: data["description"], unit: data["unit"], moq: data["moq"], lead_time: data["lead_time"], price_currency: data["currency"].presence || "USD", default_price: data["explicit_price"].presence || product.default_price || 0)
    product.save!
    candidate.update!(matched_product: product)
  end
end
