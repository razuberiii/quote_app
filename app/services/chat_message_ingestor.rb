class ChatMessageIngestor
  MAX_BATCH_SIZE = 100

  def initialize(binding:, user:, messages:)
    @binding = binding
    @user = user
    @messages = Array(messages).first(MAX_BATCH_SIZE)
  end

  def call
    accepted = []
    @messages.each do |payload|
      fingerprint = stable_fingerprint(payload)
      captured = @binding.chat_captured_messages.find_or_initialize_by(fingerprint:)
      if captured.persisted?
        accepted << captured if reconcile_direction(captured, payload)
        next
      end

      captured.assign_attributes(captured_attributes(payload, fingerprint))
      InquiryMessage.transaction do
        captured.inquiry_message = create_inquiry_message(payload)
        captured.save!
      end
      accepted << captured
    rescue ActiveRecord::RecordInvalid
      next
    end
    accepted
  end

  private

  def stable_fingerprint(payload)
    native_id = payload["platformMessageId"].to_s.strip
    return Digest::SHA256.hexdigest("native:#{@binding.platform}:#{native_id}") if native_id.present?

    source = payload["rawFingerprint"].presence || [
      @binding.platform, @binding.platform_conversation_id, payload["senderId"],
      payload["sentAt"], payload["text"], payload["type"], payload["quotedText"]
    ].join("\u241f")
    Digest::SHA256.hexdigest(source)
  end

  def captured_attributes(payload, fingerprint)
    {
      local_id: payload["localId"].presence || SecureRandom.uuid,
      platform_message_id: payload["platformMessageId"].presence,
      fingerprint:, direction: payload["direction"].presence_in(ChatCapturedMessage::DIRECTIONS) || "unknown",
      sender_id: payload["senderId"].to_s.first(255), sender_name: payload["senderName"].to_s.first(255),
      sent_at: parse_time(payload["sentAt"]), captured_at: parse_time(payload["capturedAt"]) || Time.current,
      message_type: payload["type"].presence_in(ChatCapturedMessage::MESSAGE_TYPES) || "unknown",
      text: payload["text"].to_s.first(50_000), quoted_text: payload["quotedText"].to_s.first(10_000),
      attachment_name: payload["attachmentName"].to_s.first(500),
      source_metadata: source_metadata(payload["sourceMetadata"]),
      parser_version: payload["parserVersion"].to_s.first(80).presence || "unknown"
    }
  end

  def reconcile_direction(captured, payload)
    direction = payload["direction"].presence_in(%w[customer sales])
    return false unless direction
    return false if captured.direction == direction

    captured.update!(
      direction:,
      parser_version: payload["parserVersion"].to_s.first(80).presence || captured.parser_version
    )
    captured.inquiry_message&.update!(direction: direction == "sales" ? "seller" : "buyer")
    true
  end

  def source_metadata(value)
    allowed = %w[visibleTimestamp deliveryState productId adapter]
    return value.permit(*allowed).to_h if value.respond_to?(:permit)
    return value.to_h.stringify_keys.slice(*allowed) if value.respond_to?(:to_h)

    {}
  end

  def create_inquiry_message(payload)
    type = payload["type"].presence_in(ChatCapturedMessage::MESSAGE_TYPES) || "unknown"
    body = payload["text"].to_s.strip.presence || payload["attachmentName"].to_s.strip.presence || "[#{type}]"
    @binding.inquiry.inquiry_messages.create!(
      recorded_by: @user,
      direction: payload["direction"] == "sales" ? "seller" : "buyer",
      channel: @binding.platform == "whatsapp" ? "whatsapp" : "other",
      body:, occurred_at: parse_time(payload["sentAt"]) || Time.current,
      change_summary: { "status" => "captured", "chat_sync" => true }
    )
  end

  def parse_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
