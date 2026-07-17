class QuoteRevision < ApplicationRecord
  STATUSES = %w[draft current superseded revoked expired accepted].freeze

  belongs_to :company
  belongs_to :quote
  belongs_to :created_by, class_name: "User", optional: true
  has_many :buyer_questions, dependent: :restrict_with_exception
  has_many :change_requests, dependent: :restrict_with_exception
  has_many :version_deliveries, dependent: :restrict_with_exception
  has_many :deal_responses, dependent: :restrict_with_exception
  has_one :quote_acceptance, dependent: :restrict_with_exception

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :quote_id }
  validates :currency, :secure_token, presence: true
  validates :secure_token, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :total, numericality: { greater_than_or_equal_to: 0 }
  validate :company_matches_quote

  scope :ordered, -> { order(number: :desc) }

  before_update :prevent_published_content_mutation

  IMMUTABLE_ATTRIBUTES = %w[snapshot currency total number published_at quote_id company_id].freeze

  def delivered?
    version_deliveries.where(status: %w[sent succeeded externally_sent]).exists?
  end

  def actionable?
    status == "current" && revoked_at.nil? && superseded_at.nil? && (expires_at.nil? || expires_at.future?) && quote.quote_revisions.maximum(:number) == number
  end

  def expired?
    expires_at.present? && expires_at.past?
  end

  private

  def prevent_published_content_mutation
    return if published_at_was.blank?
    changed = IMMUTABLE_ATTRIBUTES & changes.keys
    errors.add(:base, "Published Version content is immutable (#{changed.join(', ')})") if changed.any?
    throw(:abort) if changed.any?
  end

  def company_matches_quote
    errors.add(:company, "must match quote workspace") if quote && company_id != quote.company_id
  end
end
