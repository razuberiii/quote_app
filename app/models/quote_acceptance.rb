class QuoteAcceptance < ApplicationRecord
  belongs_to :company
  belongs_to :quote
  belongs_to :quote_revision
  has_one :proforma_invoice, dependent: :restrict_with_exception
  has_many :final_documents, dependent: :restrict_with_exception
  belongs_to :recorded_by, class_name: "User", optional: true
  has_many_attached :evidence_files

  METHODS = %w[buyer_room email_confirmation purchase_order signed_document external_message verbal seller_recorded].freeze
  validates :name, :currency, :accepted_at, :idempotency_key, presence: true
  validates :email, presence: true, if: -> { acceptance_method == "buyer_room" }
  validates :acceptance_method, inclusion: { in: METHODS }
  validates :quote_revision_id, uniqueness: true
  validates :total, numericality: { greater_than_or_equal_to: 0 }
end
