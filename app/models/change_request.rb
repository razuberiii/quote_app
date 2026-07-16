class ChangeRequest < ApplicationRecord
  belongs_to :company
  belongs_to :quote_revision
  validates :message, :idempotency_key, presence: true
end
