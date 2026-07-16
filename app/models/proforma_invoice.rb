class ProformaInvoice < ApplicationRecord
  STATUSES = %w[awaiting_deposit deposit_received cancelled].freeze
  belongs_to :company
  belongs_to :quote
  belongs_to :quote_acceptance
  belongs_to :created_by, class_name: "User", optional: true
  validates :number, uniqueness: { scope: :company_id }, presence: true
  validates :status, inclusion: { in: STATUSES }
end
