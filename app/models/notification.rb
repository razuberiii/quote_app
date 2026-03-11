class Notification < ApplicationRecord
  LEGACY_KIND_MAP = {
    "0" => "quote_viewed",
    "1" => "quote_accepted",
    "2" => "quote_revision_requested"
  }.freeze
  VALID_KINDS = %w[quote_viewed quote_accepted quote_revision_requested].freeze

  belongs_to :user

  scope :unread, -> { where(read_at: nil) }
  scope :unnotified, -> { where(dismissed_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  validates :kind, presence: true, inclusion: { in: VALID_KINDS + LEGACY_KIND_MAP.keys }

  before_validation :normalize_kind_value

  def mark_as_read!
    update!(read_at: Time.current) if read_at.blank?
  end

  def mark_as_dismissed!
    update!(dismissed_at: Time.current) if dismissed_at.blank?
  end

  def normalized_kind
    LEGACY_KIND_MAP.fetch(self[:kind].to_s, self[:kind].to_s)
  end

  def self.create_quote_view_notification(quote, first_viewer_country = nil)
    return unless quote.present?

    owner = owner_for(quote)
    return unless owner.present?

    create!(
      user: owner,
      kind: "quote_viewed",
      data: {
        quote_id: quote.id,
        quote_no: quote.quote_no,
        customer_name: quote.customer&.name,
        viewer_country: first_viewer_country
      }
    )
  end

  def self.create_quote_accepted_notification(quote)
    return unless quote.present?

    owner = owner_for(quote)
    return unless owner.present?

    create!(
      user: owner,
      kind: "quote_accepted",
      data: {
        quote_id: quote.id,
        quote_no: quote.quote_no,
        customer_name: quote.customer&.name
      }
    )
  end

  def self.create_quote_revision_requested_notification(quote)
    return unless quote.present?

    owner = owner_for(quote)
    return unless owner.present?

    create!(
      user: owner,
      kind: "quote_revision_requested",
      data: {
        quote_id: quote.id,
        quote_no: quote.quote_no,
        customer_name: quote.customer&.name,
        request_reason: quote.request_reason,
        client_message: quote.changes_request_message
      }
    )
  end

  # Returns the most appropriate user to receive a notification for this quote.
  # Priority: customer's designated internal owner → company owner → company admin
  def self.owner_for(quote)
    if Customer.internal_owner_enabled?
      owner = quote.customer&.internal_owner
      return owner if owner.present?
    end
    company = quote.company
    return nil unless company
    company.users.company_owner.order(:created_at).first ||
      company.users.company_admin.order(:created_at).first
  rescue StandardError
    nil
  end
  private_class_method :owner_for

  private

  def normalize_kind_value
    self[:kind] = normalized_kind if self[:kind].present?
  end
end
