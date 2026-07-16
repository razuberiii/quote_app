class BuyerActivity < ApplicationRecord
  belongs_to :company
  belongs_to :quote
  belongs_to :quote_revision, optional: true
  validates :kind, :deduplication_key, presence: true
end
