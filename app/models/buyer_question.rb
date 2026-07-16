class BuyerQuestion < ApplicationRecord
  belongs_to :company
  belongs_to :quote_revision
  validates :body, :idempotency_key, presence: true
end
