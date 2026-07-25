class ChatSyncToken < ApplicationRecord
  TTL = 90.days

  belongs_to :user
  belongs_to :company

  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.issue!(pairing_code, label: nil)
    raw_token = "rbc_#{SecureRandom.urlsafe_base64(36)}"
    token = create!(user: pairing_code.user, company: pairing_code.company,
      token_digest: digest(raw_token), expires_at: TTL.from_now, label:)
    [ token, raw_token ]
  end

  def self.authenticate(raw_token)
    active.includes(:user, :company).find_by(token_digest: digest(raw_token.to_s))
  end

  def touch_usage!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 15.minutes.ago
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
