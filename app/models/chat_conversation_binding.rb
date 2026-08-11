class ChatConversationBinding < ApplicationRecord
  PLATFORMS = %w[whatsapp alibaba generic].freeze

  belongs_to :company
  belongs_to :user
  belongs_to :customer, optional: true
  belongs_to :inquiry
  has_many :chat_sync_requests, dependent: :destroy
  has_many :chat_captured_messages, dependent: :destroy

  validates :platform, inclusion: { in: PLATFORMS }
  validates :platform_account_id, :platform_conversation_id, presence: true
  validates :platform_conversation_id, uniqueness: {
    scope: %i[company_id platform platform_account_id]
  }

  def current_captured_messages
    chat_captured_messages.joins(:inquiry_message).where(inquiry_messages: { inquiry_id: inquiry_id })
  end
end
