class User < ApplicationRecord
  attr_writer :login
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  FREE_CUSTOMER_LIMIT = 5
  FREE_QUOTE_LIMIT = 20
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_AVATAR_SIZE = 5.megabytes

  enum :role, { user: 0, vip: 1, admin: 2 }, default: :user
  enum :status, { active: 0, suspended: 1 }, default: :active
  enum :company_role, { owner: 0, admin: 1, member: 2 }, default: :member, prefix: :company
  validates :language, inclusion: { in: %w[en zh-CN es-419] }, allow_blank: true
  validates :username, presence: true, length: { in: 3..32 },
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "may contain only letters, numbers, and underscores" },
    uniqueness: { case_sensitive: false }

  belongs_to :company
  has_many :action_items, dependent: :destroy
  has_many :customer_follow_up_events, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :sent_team_invitations, class_name: "TeamInvitation", foreign_key: :invited_by_id, dependent: :destroy
  has_one_attached :avatar
  before_validation :ensure_company, on: :create
  before_validation :assign_company_role, on: :create
  before_validation :assign_default_username, on: :create
  before_validation :normalize_username
  validate :avatar_constraints

  def can_create_customer?
    return true if company_unlimited_plan?

    customer_count_for_limit < FREE_CUSTOMER_LIMIT
  end

  def can_create_quote?
    return true if company_unlimited_plan?

    quote_count_for_limit < FREE_QUOTE_LIMIT
  end

  def customer_count_for_limit
    company.customers.count
  end

  def quote_count_for_limit
    company.quotes.not_archived.where.not(quote_no: nil).distinct.count(:quote_no)
  end

  def can_manage_team?
    company_owner? || company_admin?
  end

  def can_manage_templates?
    company_owner? || company_admin?
  end

  def company_unlimited_plan?
    return false if company.blank?

    company.users.where(
      "role = :admin_role OR (role = :vip_role AND (vip_expires_at IS NULL OR vip_expires_at > :now))",
      admin_role: User.roles[:admin],
      vip_role: User.roles[:vip],
      now: Time.current
    ).exists?
  end

  def grant_vip_for!(duration)
    now = Time.current
    base_time = [ vip_expires_at, now ].compact.max
    update!(role: :vip, vip_expires_at: base_time + duration)
  end

  def email_verified?
    email_verified_at.present?
  end

  def active_for_app?
    active?
  end

  def login
    @login || username || email
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = (conditions.delete(:login).presence || conditions.delete(:email)).to_s.strip.downcase
    where(conditions).where("LOWER(username) = :value OR LOWER(email) = :value", value: login).first
  end

  def move_to_personal_company!
    transaction do
      personal_company = Company.create!(name: "#{email}'s Company")
      update!(company: personal_company, company_role: :owner)
    end
  end

  private

  def assign_default_username
    return if username.present?

    base = email.to_s.split("@").first.to_s.gsub(/[^a-zA-Z0-9_]/, "_").downcase.presence || "user"
    self.username = User.where("LOWER(username) = ?", base).exists? ? "#{base}_#{SecureRandom.hex(3)}" : base
  end

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def ensure_company
    self.company ||= Company.create!(name: "My Company")
  end

  def assign_company_role
    return if company.blank?

    self.company_role = if company.users.where.not(id: id).exists?
      company_role.presence || "member"
    else
      "owner"
    end
  end

  def avatar_constraints
    return unless avatar.attached?

    if !AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be PNG, JPG, WEBP, or GIF")
    end
    if avatar.blob.byte_size > MAX_AVATAR_SIZE
      errors.add(:avatar, "must be smaller than #{MAX_AVATAR_SIZE / 1.megabyte}MB")
    end
  end
end
