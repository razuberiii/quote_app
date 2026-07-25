class ChatCapturedMessage < ApplicationRecord
  DIRECTIONS = %w[customer sales unknown].freeze
  MESSAGE_TYPES = %w[text image file audio system product unknown].freeze

  belongs_to :chat_conversation_binding
  belongs_to :inquiry_message, optional: true

  validates :local_id, :fingerprint, :captured_at, :parser_version, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :message_type, inclusion: { in: MESSAGE_TYPES }
  validates :fingerprint, uniqueness: { scope: :chat_conversation_binding_id }
  validate :business_content_present

  private

  def business_content_present
    errors.add(:text, :blank) if text.blank? && attachment_name.blank? && message_type == "text"
  end
end
