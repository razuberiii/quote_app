class TeamInvitation < ApplicationRecord
  MAX_ACTIVE_INVITATIONS_PER_COMPANY = 50

  belongs_to :company
  belongs_to :invited_by, class_name: "User"

  enum :company_role, { admin: 0, member: 1 }, default: :member, prefix: :company

  validates :email, presence: true
  validates :token, presence: true, uniqueness: true
  validate :active_invitation_count_limit, on: :create

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

  def active_invitation_count_limit
    return if company.blank?
    active_count = company.team_invitations.active.where.not(id: id).count
    return if active_count < MAX_ACTIVE_INVITATIONS_PER_COMPANY

    errors.add(:base, "active invitation limit reached")
  end
end
