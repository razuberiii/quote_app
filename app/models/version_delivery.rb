class VersionDelivery < ApplicationRecord
  CHANNELS = %w[buyer_room_link email_link email_pdf email_link_pdf pdf_download excel_export external printed].freeze
  EXTERNAL_CHANNELS = %w[whatsapp wechat line other_messaging phone in_person other].freeze
  SYSTEM_CHANNELS = %w[buyer_room_link email_link email_pdf email_link_pdf pdf_download excel_export].freeze
  EXTERNAL_CHANNELS_LIST = %w[external printed].freeze
  STATUSES = %w[draft queued sent succeeded failed generated downloaded externally_sent revoked].freeze

  belongs_to :company
  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :retry_of, class_name: "VersionDelivery", optional: true
  has_many :retries, class_name: "VersionDelivery", foreign_key: :retry_of_id, dependent: :nullify, inverse_of: :retry_of
  has_one_attached :evidence
  has_one_attached :generated_file

  validates :channel, inclusion: { in: CHANNELS }
  validates :external_channel, inclusion: { in: EXTERNAL_CHANNELS }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: { scope: :quote_revision_id }
  validate :relations_share_company

  def view_status_label
    channel.start_with?("buyer_room", "email_link") ? "Buyer Room activity available" : "View status unavailable"
  end

  def system_executed?
    SYSTEM_CHANNELS.include?(channel)
  end

  def successful?
    %w[sent succeeded externally_sent].include?(status)
  end

  private

  def relations_share_company
    errors.add(:quote, "must belong to the same workspace") if quote && quote.company_id != company_id
    errors.add(:quote_revision, "must belong to the same Deal") if quote_revision && quote_revision.quote_id != quote_id
  end
end
