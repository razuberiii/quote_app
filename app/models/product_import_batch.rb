class ProductImportBatch < ApplicationRecord
  STATUSES = %w[processing review applied failed].freeze

  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true
  has_many :product_import_candidates, dependent: :destroy
  has_many_attached :source_files

  validates :status, inclusion: { in: STATUSES }
  validates :input_fingerprint, presence: true

  def incomplete_ranges
    Array(processing_report).select { |range| range["status"].in?(%w[unrecognized failed]) }
  end
end
