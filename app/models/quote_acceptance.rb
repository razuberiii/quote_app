class QuoteAcceptance < ApplicationRecord
  belongs_to :company
  belongs_to :quote
  belongs_to :quote_revision
  has_one :proforma_invoice, dependent: :restrict_with_exception

  validates :name, :email, :currency, :accepted_at, :idempotency_key, presence: true
  validates :quote_revision_id, uniqueness: true
  validates :total, numericality: { greater_than_or_equal_to: 0 }
end
