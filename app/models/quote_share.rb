class QuoteShare < ApplicationRecord
  belongs_to :company
  belongs_to :quote

  validates :token, presence: true, uniqueness: true
  validates :snapshot, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.generate_token
    SecureRandom.hex(12)
  end
end
