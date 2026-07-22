class ProductImportBatchProcessingJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(batch_id)
    batch = ProductImportBatch.find(batch_id)
    ProductImportBatchProcessor.new(batch).call
  end
end
