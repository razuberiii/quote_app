class InquiryConversationUpdater
  def initialize(inquiry, message)
    @inquiry = inquiry
    @message = message
  end

  def call
    before = @inquiry.extracted_data.deep_dup.deep_stringify_keys
    @inquiry.update!(source_text: @inquiry.conversation_source)
    @inquiry.source_type == "manual" ? @inquiry.manually_extract! : @inquiry.extract_requirements!
    summary = summarize(before, @inquiry.extracted_data.deep_stringify_keys)
    @message.update!(change_summary: summary)
    summary
  end

  private

  def summarize(before, after)
    changed = %w[customer contact_name contact_email country currency].filter_map do |key|
      next if before[key] == after[key]
      { "field" => key, "from" => before[key], "to" => after[key] }
    end
    old_terms = before.fetch("commercial_terms", {})
    new_terms = after.fetch("commercial_terms", {})
    changed.concat(%w[destination incoterm delivery packing].filter_map do |key|
      next if old_terms[key] == new_terms[key]
      { "field" => key, "from" => old_terms[key], "to" => new_terms[key] }
    end)
    outcome = if changed.any? || Array(before["products"]).size != Array(after["products"]).size
      "quote_changed"
    elsif Array(after["missing_information"]).any? || Array(after["questions"]).any?
      "follow_up"
    else
      "no_action"
    end
    {
      "outcome" => outcome,
      "changed" => changed,
      "products_before" => Array(before["products"]).size,
      "products_after" => Array(after["products"]).size,
      "missing" => Array(after["missing_information"]),
      "questions" => Array(after["questions"])
    }
  end
end
