class ChatSyncRequest < ApplicationRecord
  belongs_to :chat_conversation_binding
  validates :request_id, presence: true, uniqueness: { scope: :chat_conversation_binding_id }
end
