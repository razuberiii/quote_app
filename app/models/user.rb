class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  FREE_CUSTOMER_LIMIT = 5
  FREE_QUOTE_LIMIT = 20

  enum :role, { user: 0, vip: 1, admin: 2 }, default: :user
  enum :company_role, { owner: 0, admin: 1, member: 2 }, default: :member, prefix: :company
  validates :language, inclusion: { in: %w[en zh-CN es-419] }, allow_blank: true

  belongs_to :company
  has_many :action_items, dependent: :destroy
  has_many :sent_team_invitations, class_name: "TeamInvitation", foreign_key: :invited_by_id, dependent: :destroy
  has_one_attached :avatar
  before_validation :ensure_company, on: :create
  before_validation :assign_company_role, on: :create

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

    company.users.where(role: [ User.roles[:vip], User.roles[:admin] ]).exists?
  end

  def email_verified?
    email_verified_at.present?
  end

  def move_to_personal_company!
    transaction do
      personal_company = Company.create!(name: "#{email}'s Company")
      update!(company: personal_company, company_role: :owner)
    end
  end

  private

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
end
