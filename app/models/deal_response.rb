class DealResponse < ApplicationRecord
  KINDS = %w[email_reply buyer_file returned_excel returned_pdf purchase_order external_message phone_note seller_note].freeze
  SOURCES = %w[email upload excel pdf purchase_order whatsapp wechat line phone in_person other seller].freeze
  STATUSES = %w[open reviewed applied evidence_only].freeze
  CONTEXT_TYPES = %w[quote product configuration fee term attachment].freeze

  belongs_to :company
  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :recorded_by, class_name: "User", optional: true
  has_one_attached :attachment

  validates :kind, inclusion: { in: KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :context_type, inclusion: { in: CONTEXT_TYPES }
  validates :received_at, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: { scope: :quote_id }
  validate :safe_spreadsheet_attachment

  private

  def safe_spreadsheet_attachment
    return unless attachment.attached? && kind == "returned_excel"
    errors.add(:attachment, "must be an Excel or CSV file") unless %w[
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-excel text/csv application/csv
    ].include?(attachment.blob.content_type)
  end
end
