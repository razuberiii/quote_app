class Customer < ApplicationRecord
  belongs_to :company
  has_many :quotes, dependent: :destroy

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
end
