require "test_helper"

class ChatSyncApiTest < ActionDispatch::IntegrationTest
  test "pairs once, binds a conversation, and uploads a batch idempotently" do
    code = ChatPairingCode.issue!(users(:one))

    post "/api/chat_sync/pair", params: { code:, label: "Test browser" }, as: :json
    assert_response :created
    token = response.parsed_body.fetch("token")

    post "/api/chat_sync/pair", params: { code: }, as: :json
    assert_response :unprocessable_entity

    headers = { "Authorization" => "Bearer #{token}" }
    post "/api/chat_sync/bindings", params: {
      platform: "whatsapp",
      platformAccountId: "sales@example.com",
      platformConversationId: "buyer-42",
      displayName: "Maria",
      customerId: customers(:one).id
    }, headers:, as: :json
    assert_response :created
    binding_id = response.parsed_body.dig("binding", "id")

    message = {
      localId: "local-1",
      platformMessageId: "wa-1",
      direction: "customer",
      senderName: "Maria",
      sentAt: "2026-07-25T09:00:00Z",
      capturedAt: "2026-07-25T09:00:01Z",
      type: "text",
      text: "Please quote five units",
      rawFingerprint: "client-fingerprint",
      parserVersion: "test-1"
    }
    path = "/api/chat_sync/bindings/#{binding_id}/messages"
    post path, params: { requestId: "request-1", messages: [ message ] }, headers:, as: :json
    assert_response :created
    assert_equal 1, response.parsed_body.fetch("acceptedCount")

    post path, params: { requestId: "request-1", messages: [ message ] }, headers:, as: :json
    assert_response :success
    assert response.parsed_body.fetch("duplicateRequest")
    assert_equal 1, ChatCapturedMessage.where(chat_conversation_binding_id: binding_id).count
  end

  test "rejects missing chat sync token" do
    get "/api/chat_sync/context"
    assert_response :unauthorized
  end
end
