class Customer < ApplicationRecord
  SALES_STATUSES = %w[new contacted quoting negotiating won lost inactive].freeze
  LEGACY_STATUSES = %w[potential following closed paused].freeze

  belongs_to :company
  has_many :quotes, dependent: :destroy

  before_validation :set_default_status

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

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
    status.to_s.humanize.presence || "New"
  end

  def status_css
    normalized = status.to_s.parameterize(separator: "_")
    normalized.presence || "new"
  end

  private

  def set_default_status
    self.status = "new" if status.blank?
  end
end
