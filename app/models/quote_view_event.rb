class QuoteViewEvent < ApplicationRecord
  belongs_to :quote_share

  validates :duration_ms, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
end
