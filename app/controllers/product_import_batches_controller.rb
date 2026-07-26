class ProductImportBatchesController < ApplicationController
  before_action :set_batch, only: %i[show update apply retry_processing]

  def new
    active_batch = current_user.company.product_import_batches.where(status: "processing").order(created_at: :desc).first
    return redirect_to active_batch if active_batch

    @batch = current_user.company.product_import_batches.new
  end

  def create
    files = Array(params.dig(:product_import_batch, :source_files)).reject(&:blank?)
    return redirect_to new_product_import_batch_path, alert: t("self_service.catalog_import.errors.file_required") if files.empty?

    @batch = current_user.company.product_import_batches.create!(created_by: current_user,
      input_fingerprint: "processing:#{SecureRandom.hex(16)}", status: "processing")
    @batch.source_files.attach(files)
    ProductImportBatchProcessingJob.perform_later(@batch.id)
    redirect_to @batch
  end

  def show
    @candidates = @batch.product_import_candidates.includes(:matched_product).order(:id)
    @products = current_user.company.products.order(:name)
    respond_to do |format|
      format.html
      format.json { render json: { status: @batch.status, candidate_count: @candidates.size } }
    end
  end

  def active
    batch = current_user.company.product_import_batches.where(status: %w[processing review failed])
      .order(created_at: :desc).first
    return head :no_content unless batch

    render json: {
      id: batch.id,
      status: batch.status,
      candidateCount: batch.product_import_candidates.count,
      path: product_import_batch_path(batch),
      label: active_batch_label(batch)
    }
  end

  def retry_processing
    @batch.product_import_candidates.destroy_all
    @batch.update!(status: "processing", warnings: [])
    ProductImportBatchProcessingJob.perform_later(@batch.id)
    redirect_to @batch, notice: t("self_service.catalog_import.flash.retry_started")
  end

  def update
    persist_review!
    redirect_to @batch, notice: t("self_service.catalog_import.flash.review_saved")
  end

  def apply
    persist_review!
    count = ProductImportBatchApplier.new(batch: @batch).call
    redirect_to library_path, notice: t("self_service.catalog_import.flash.applied", count:)
  rescue ProductImportBatchApplier::NoCandidatesSelected
    redirect_to @batch, alert: t("self_service.catalog_import.errors.no_candidates_selected")
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

  def active_batch_label(batch)
    case batch.status
    when "processing"
      t("self_service.catalog_task.processing")
    when "review"
      t("self_service.catalog_task.review", count: batch.product_import_candidates.count)
    else
      t("self_service.catalog_task.failed")
    end
  end
end
