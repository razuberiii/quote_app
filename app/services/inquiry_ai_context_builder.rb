class InquiryAiContextBuilder
  MAX_CHARACTERS = 32_000
  HEAD_MESSAGES = 2

  def initialize(inquiry, max_characters: MAX_CHARACTERS)
    @inquiry = inquiry
    @max_characters = max_characters
  end

  def call
    messages = @inquiry.inquiry_messages.includes(chat_captured_message: :chat_conversation_binding).to_a
    return @inquiry.source_text.to_s.first(@max_characters) if messages.empty?

    facts = @inquiry.extracted_data.to_h.slice("customer", "contact_name", "contact_email", "country", "currency", "products", "commercial_terms")
    prefix = "Current task facts (previously extracted; verify changes): #{facts.to_json}\n\n"
    rendered = messages.map { |message| render_message(message) }
    selected = rendered.first(HEAD_MESSAGES)
    remaining = @max_characters - prefix.length - selected.sum(&:length) - 160
    tail = []
    rendered.drop(HEAD_MESSAGES).reverse_each do |entry|
      break if remaining < entry.length

      tail.unshift(entry)
      remaining -= entry.length
    end
    omitted = rendered.length - selected.length - tail.length
    marker = omitted.positive? ? "\n[#{omitted} earlier messages omitted from this AI pass; original messages remain stored]\n\n" : ""
    "#{prefix}#{selected.join("\n\n")}#{marker}#{tail.join("\n\n")}".first(@max_characters)
  end

  private

  def render_message(message)
    captured = message.chat_captured_message
    role = { "buyer" => "customer", "seller" => "our_sales", "internal" => "other" }.fetch(message.direction)
    message_id = captured&.platform_message_id.presence || "local-#{message.id}"
    sender = captured&.sender_name.presence
    header = [ "message_id=#{message_id}", "role=#{role}", "type=#{captured&.message_type || "text"}",
      "channel=#{message.channel}", "sent_at=#{message.occurred_at.iso8601}", ("sender=#{sender}" if sender) ].compact.join(" | ")
    "[#{header}]\n#{message.body.to_s.squish}"
  end
end
