class ContactRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  INQUIRY_TYPES = %w[general vip support].freeze

  attribute :name, :string
  attribute :email, :string
  attribute :company, :string
  attribute :team_size, :string
  attribute :inquiry_type, :string, default: "general"
  attribute :message, :string
  attribute :website, :string
  attribute :cf_turnstile_response, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { minimum: 10, maximum: 3000 }
  validates :inquiry_type, inclusion: { in: INQUIRY_TYPES }
  validate :honeypot_must_be_blank

  def normalized_inquiry_type
    inquiry_type.to_s.downcase
  end

  private

  def honeypot_must_be_blank
    errors.add(:base, "Invalid submission") if website.present?
  end
end
