class ChatConversationTaskRouter
  TERMINAL_QUOTE_STATUSES = %w[won lost cancelled expired archived].freeze

  def initialize(binding:, user:, messages:)
    @binding = binding
    @user = user
    @messages = Array(messages)
  end

  def call
    quote = @binding.inquiry.quote
    return @binding.inquiry unless quote&.status.in?(TERMINAL_QUOTE_STATUSES)
    return @binding.inquiry unless unseen_message?
    return @binding.inquiry unless new_quote_intent?

    @binding.with_lock do
      quote = @binding.inquiry.quote
      return @binding.inquiry unless quote&.status.in?(TERMINAL_QUOTE_STATUSES)

      previous_inquiry = @binding.inquiry
      previous_data = previous_inquiry.extracted_data.to_h.deep_dup
      previous_data["task_context"] = previous_data.fetch("task_context", {}).merge(
        "platform" => @binding.platform, "conversation_name" => @binding.display_name)
      previous_inquiry.update_columns(extracted_data: previous_data)
      inquiry = @binding.company.inquiries.create!(customer: @binding.customer, created_by: @user,
        source_type: "chat", status: "review", source_text: "",
        extracted_data: { "task_context" => { "reason" => "new_messages_after_closed_quote", "previous_quote_id" => quote.id,
          "platform" => @binding.platform, "conversation_name" => @binding.display_name } })
      @binding.update!(inquiry:, analysis_result: {}, analyzed_message_cursor: nil, last_analyzed_at: nil)
      inquiry
    end
  end

  private

  def unseen_message?
    fingerprints = @messages.map { |payload| ChatMessageIngestor.fingerprint_for(@binding, payload) }
    fingerprints.any? && @binding.chat_captured_messages.where(fingerprint: fingerprints).count < fingerprints.uniq.count
  end

  def new_quote_intent?
    @messages.any? do |payload|
      next false unless payload["direction"].to_s == "customer"

      payload["text"].to_s.match?(/\b(?:new\s+(?:order|inquiry)|please\s+quote|quote\s+(?:for|us)|rfq)\b|(?:新订单|新询盘|请报价|重新报价|再报|需要)\s*[^\n]{0,80}(?:\d+\s*(?:台|套|件|个)|型号)/i)
    end
  end
end
