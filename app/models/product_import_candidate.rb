class ProductImportCandidate < ApplicationRecord
  DECISIONS = %w[pending create merge variant ignore].freeze

  belongs_to :product_import_batch
  belongs_to :matched_product, class_name: "Product", optional: true

  validates :decision, inclusion: { in: DECISIONS }
  validates :confidence, numericality: { in: 0..1 }, allow_nil: true
end
