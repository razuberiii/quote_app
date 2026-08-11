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
    inquiry_id = response.parsed_body.dig("binding", "inquiryId")

    assert_no_difference "Inquiry.count" do
      post "/api/chat_sync/bindings", params: {
        platform: "whatsapp", platformAccountId: "sales@example.com",
        platformConversationId: "buyer-42", displayName: "Maria updated"
      }, headers:, as: :json
    end
    assert_equal inquiry_id, response.parsed_body.dig("binding", "inquiryId")

    message = {
      localId: "local-1",
      platformMessageId: "wa-1",
      direction: "customer",
      senderName: "Maria",
      sentAt: "2026-07-25T09:00:00Z",
      capturedAt: "2026-07-25T09:00:01Z",
      type: "text",
      text: "Please quote five units",
      sourceMetadata: {
        visibleTimestamp: "09:00",
        adapter: "whatsapp-v1",
        ignored: "not persisted"
      },
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
    captured = ChatCapturedMessage.find_by!(chat_conversation_binding_id: binding_id)
    assert_equal({ "visibleTimestamp" => "09:00", "adapter" => "whatsapp-v1" }, captured.source_metadata)

    corrected = message.merge(direction: "sales", parserVersion: "whatsapp-v2")
    post path, params: { requestId: "request-2", messages: [ corrected ] }, headers:, as: :json
    assert_response :created
    assert_equal 1, response.parsed_body.fetch("acceptedCount")
    assert_equal 1, response.parsed_body.fetch("messageCount")
    assert_equal "sales", captured.reload.direction
    assert_equal "seller", captured.inquiry_message.direction
  end

  test "rejects missing chat sync token" do
    get "/api/chat_sync/context"
    assert_response :unauthorized
  end

  test "unknown message direction remains neutral before AI analysis" do
    binding = ChatConversationBinding.create!(company: companies(:one), user: users(:one),
      inquiry: Inquiry.create!(company: companies(:one), created_by: users(:one), source_type: "chat", source_text: ""),
      platform: "alibaba", platform_account_id: "seller-1", platform_conversation_id: "thread-1")

    captured = ChatMessageIngestor.new(binding:, user: users(:one), messages: [ {
      "platformMessageId" => "system-1", "direction" => "unknown", "type" => "system",
      "text" => "Conversation started", "capturedAt" => Time.current.iso8601, "parserVersion" => "test"
    } ]).call.first

    assert_equal "unknown", captured.direction
    assert_equal "internal", captured.inquiry_message.direction
    assert_match(/message_id=system-1 \| role=other \| type=system/, binding.inquiry.conversation_source)
  end

  test "new messages after a terminal quote start a new inquiry for the same conversation" do
    code = ChatPairingCode.issue!(users(:one))
    post "/api/chat_sync/pair", params: { code:, label: "Cycle browser" }, as: :json
    token = response.parsed_body.fetch("token")
    headers = { "Authorization" => "Bearer #{token}" }
    post "/api/chat_sync/bindings", params: {
      platform: "whatsapp", platformAccountId: "sales@example.com",
      platformConversationId: "repeat-buyer", displayName: "Repeat buyer", customerId: customers(:one).id
    }, headers:, as: :json
    binding = ChatConversationBinding.find(response.parsed_body.dig("binding", "id"))
    previous_inquiry = binding.inquiry
    quotes(:one).update_columns(inquiry_id: previous_inquiry.id, status: "won")

    post "/api/chat_sync/bindings/#{binding.id}/messages", params: {
      requestId: "new-order-1", messages: [ {
        platformMessageId: "wa-new-order", direction: "customer", senderName: "Maria",
        sentAt: Time.current.iso8601, type: "text", text: "This is a new order for 8 sets"
      } ]
    }, headers:, as: :json

    assert_response :created
    refute_equal previous_inquiry.id, binding.reload.inquiry_id
    assert_equal "new_messages_after_closed_quote", binding.inquiry.extracted_data.dig("task_context", "reason")
    assert_equal "whatsapp", previous_inquiry.reload.extracted_data.dig("task_context", "platform")
    assert_equal 1, binding.inquiry.inquiry_messages.count
    assert_equal previous_inquiry.id, quotes(:one).reload.inquiry_id
  end

  test "replaying an existing message does not create a new task after quote closure" do
    binding = ChatConversationBinding.create!(company: companies(:one), user: users(:one), customer: customers(:one),
      inquiry: Inquiry.create!(company: companies(:one), customer: customers(:one), created_by: users(:one), source_type: "chat"),
      platform: "whatsapp", platform_account_id: "sales-2", platform_conversation_id: "thread-replay")
    message = { "platformMessageId" => "wa-existing", "direction" => "customer", "text" => "Old order" }
    ChatMessageIngestor.new(binding:, user: users(:one), messages: [ message ]).call
    quotes(:one).update_columns(inquiry_id: binding.inquiry_id, status: "won")

    result = ChatConversationTaskRouter.new(binding:, user: users(:one), messages: [ message ]).call
    assert_equal binding.inquiry_id, result.id
  end

  test "a post-sale message does not start a new quote task" do
    binding = ChatConversationBinding.create!(company: companies(:one), user: users(:one), customer: customers(:one),
      inquiry: Inquiry.create!(company: companies(:one), customer: customers(:one), created_by: users(:one), source_type: "chat"),
      platform: "whatsapp", platform_account_id: "sales-3", platform_conversation_id: "thread-thanks")
    quotes(:one).update_columns(inquiry_id: binding.inquiry_id, status: "won")
    message = { "platformMessageId" => "wa-thanks", "direction" => "customer", "text" => "Thank you, shipment received." }

    result = ChatConversationTaskRouter.new(binding:, user: users(:one), messages: [ message ]).call
    assert_equal binding.inquiry_id, result.id
  end
end
