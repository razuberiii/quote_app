class ChatReadinessAnalysis
  def initialize(binding)
    @binding = binding
    @inquiry = binding.inquiry
    @data = @inquiry.extracted_data.to_h
  end

  def call
    products = Array(@data["products"])
    terms = @data["commercial_terms"].to_h
    confirmed = []
    missing = []
    add_requirement(confirmed, missing, "customer", @data["customer"])
    add_requirement(confirmed, missing, "currency", @data["currency"])
    add_requirement(confirmed, missing, "products", products.presence)
    add_requirement(confirmed, missing, "destination", terms["destination"])
    add_requirement(confirmed, missing, "incoterm", terms["incoterm"])
    add_requirement(confirmed, missing, "delivery", terms["delivery"])

    conflicts = @inquiry.field_states.to_h.select { |_key, value| value == "conflict" }.keys
    preliminary = @data["customer"].present? && @data["currency"].present? &&
      products.any? { |product| product["name"].present? && product["quantity"].to_d.positive? }
    formal = preliminary && terms["destination"].present? && terms["incoterm"].present?
    status = if conflicts.any?
      "conflict"
    elsif formal
      "formal_ready"
    elsif preliminary
      "preliminary_ready"
    else
      "insufficient"
    end
    cursor = @binding.current_captured_messages.maximum(:id)

    {
      "status" => "complete",
      "readinessStatus" => status,
      "readinessScore" => readiness_score(confirmed, missing, conflicts),
      "confirmedRequirements" => confirmed,
      "missingRequirements" => missing,
      "conflictingRequirements" => conflicts.map { |key| { "key" => key } },
      "requirementChanges" => recent_changes,
      "suggestedNextActions" => next_actions(status),
      "suggestedQuestions" => InquiryClarificationPrompt.new(@inquiry).questions,
      "canGenerateDraft" => preliminary && conflicts.empty?,
      "analysisVersion" => "chat-readiness-v1",
      "analyzedMessageCursor" => cursor,
      "sourceMessageIds" => @binding.current_captured_messages.order(id: :desc).limit(20).pluck(:id).reverse
    }
  end

  private

  def add_requirement(confirmed, missing, key, value)
    target = value.present? ? confirmed : missing
    target << { "key" => key, "value" => value }
  end

  def readiness_score(confirmed, missing, conflicts)
    total = confirmed.size + missing.size
    return 0 if total.zero?

    score = (confirmed.size.to_f / total * 100).round
    [ score - conflicts.size * 20, 0 ].max
  end

  def recent_changes
    @inquiry.inquiry_messages.order(id: :desc).limit(10).filter_map do |message|
      summary = message.change_summary.to_h
      next if summary["changed"].blank?

      { "messageId" => message.id, "fields" => Array(summary["changed"]) }
    end
  end

  def next_actions(status)
    case status
    when "formal_ready" then [ "review_and_generate_formal_quote" ]
    when "preliminary_ready" then [ "generate_preliminary_quote", "confirm_missing_commercial_terms" ]
    when "conflict" then [ "resolve_conflicting_requirements" ]
    else [ "ask_for_missing_requirements" ]
    end
  end
end
