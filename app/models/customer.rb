class Customer < ApplicationRecord
  SALES_STATUSES = %w[new contacted quoting negotiating won lost inactive].freeze
  LEGACY_STATUSES = %w[potential following closed paused].freeze
  CUSTOMER_LEVELS = %w[normal vip distributor key_account].freeze
  CUSTOMER_SOURCES = %w[alibaba exhibition google_seo referral old_customer other].freeze
  PAYMENT_TERMS_OPTIONS = %w[t_t l_c oa mixed].freeze

  belongs_to :company
  if column_names.include?("internal_owner_id")
    belongs_to :internal_owner, class_name: "User", optional: true
  end
  has_many :quotes, dependent: :destroy
  has_many :customer_taggings, -> { ordered }, dependent: :destroy
  has_many :customer_tags, through: :customer_taggings
  has_one_attached :avatar

  before_validation :set_default_status, :set_default_customer_level

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :customer_level, inclusion: { in: CUSTOMER_LEVELS }
  validates :customer_source, inclusion: { in: CUSTOMER_SOURCES }, allow_blank: true
  validates :payment_terms, inclusion: { in: PAYMENT_TERMS_OPTIONS }, allow_blank: true
  validates :estimated_annual_volume, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true
  validate :internal_owner_within_company

  scope :search, ->(query) {
    return all if query.blank?

    query = "%#{query}%"
    where(
      "name ILIKE ? OR country ILIKE ? OR contact_name ILIKE ? OR email ILIKE ?",
      query, query, query, query
    )
  }

  def mark_followed_today!
    update!(
      last_follow_up_date: Date.today,
      next_follow_up_date: Date.today + 3.days
    )
  end

  def follow_up_overdue?
    next_follow_up_date.present? && next_follow_up_date < Date.today
  end

  def follow_up_due_today?
    next_follow_up_date.present? && next_follow_up_date == Date.today
  end

  def follow_up_upcoming?
    next_follow_up_date.present? &&
      next_follow_up_date > Date.today &&
      next_follow_up_date <= Date.today + 7.days
  end

  def follow_up_status
    return "overdue" if follow_up_overdue?
    return "today" if follow_up_due_today?
    return "upcoming" if follow_up_upcoming?
    "normal"
  end

  def status_label
    normalized = status_css
    I18n.t("customers.status_labels.#{normalized}", default: status.to_s.humanize.presence || I18n.t("customers.status_labels.new", default: "New"))
  end

  def status_css
    normalized = status.to_s.parameterize(separator: "_")
    normalized.presence || "new"
  end

  def avatar_initial
    name.to_s.strip.first&.upcase || "?"
  end

  def ordered_tag_names
    customer_taggings.includes(:customer_tag).map { |tagging| tagging.customer_tag.name }
  end

  def ordered_customer_tags
    customer_taggings.includes(:customer_tag).map(&:customer_tag)
  end

  def internal_owner_display_name
    return "-" unless internal_owner_enabled?
    return "-" unless respond_to?(:internal_owner) && internal_owner

    internal_owner.full_name.presence || internal_owner.email
  end

  def self.internal_owner_enabled?
    column_names.include?("internal_owner_id")
  end

  def internal_owner_enabled?
    self.class.internal_owner_enabled?
  end

  private

  def set_default_status
    self.status = "new" if status.blank?
  end

  def set_default_customer_level
    self.customer_level = "normal" if customer_level.blank?
  end

  def internal_owner_within_company
    return unless internal_owner_enabled?
    return unless respond_to?(:internal_owner)
    return if internal_owner.blank? || internal_owner.company_id == company_id

    errors.add(:internal_owner, "must belong to the same company")
  end
end
