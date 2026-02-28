class TeamInvitation < ApplicationRecord
  belongs_to :company
  belongs_to :invited_by, class_name: "User"

  enum :company_role, { admin: 0, member: 1 }, default: :member, prefix: :company

  validates :email, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :normalize_email
  before_validation :ensure_token
  before_validation :ensure_expiry

  scope :active, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def accept!(user)
    raise ArgumentError, "Invitation already accepted" if accepted_at.present?
    raise ArgumentError, "Invitation expired" if expires_at <= Time.current
    raise ArgumentError, "Email does not match invite" unless user.email.to_s.downcase == email.to_s.downcase

    transaction do
      user.update!(company: company, company_role: company_role)
      update!(accepted_at: Time.current)
    end
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_token
    self.token ||= SecureRandom.hex(16)
  end

  def ensure_expiry
    self.expires_at ||= 7.days.from_now
  end
end
