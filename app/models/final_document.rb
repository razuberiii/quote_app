class FinalDocument < ApplicationRecord
  TYPES = %w[proforma_invoice order_confirmation final_quotation commercial_offer custom].freeze
  STATUSES = %w[draft sent cancelled].freeze

  belongs_to :company
  belongs_to :quote
  belongs_to :quote_acceptance
  belongs_to :created_by, class_name: "User", optional: true

  validates :document_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :title, :number, :currency, presence: true
  validates :number, uniqueness: { scope: :company_id }
  validates :total, numericality: { greater_than_or_equal_to: 0 }
end
