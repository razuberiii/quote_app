class ChatPairingCode < ApplicationRecord
  TTL = 10.minutes

  belongs_to :user
  belongs_to :company

  validates :code_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.issue!(user)
    raw_code = Array.new(3) { SecureRandom.random_number(1000).to_s.rjust(3, "0") }.join("-")
    create!(user:, company: user.company, code_digest: digest(raw_code), expires_at: TTL.from_now)
    raw_code
  end

  def self.consume!(raw_code)
    transaction do
      record = lock.find_by!(code_digest: digest(raw_code.to_s.strip))
      raise ActiveRecord::RecordNotFound if record.used_at? || record.expires_at <= Time.current

      record.update!(used_at: Time.current)
      record
    end
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
end
