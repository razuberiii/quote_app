class Inquiry < ApplicationRecord
  FIELD_STATES = %w[confirmed matched uncertain missing conflict].freeze
  belongs_to :company
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_one_attached :source_file
  has_many :inquiry_messages, -> { order(:occurred_at, :id) }, dependent: :destroy
  has_many :chat_conversation_bindings, dependent: :destroy
  has_one :quote, dependent: :nullify
  validates :source_type, inclusion: { in: %w[email chat text excel csv pdf image manual] }

  def manually_extract!
    task_context = extracted_data.to_h["task_context"]
    candidates = InquiryDeterministicParser.new(source_text).call
    self.extracted_data = {
      "raw_requirements" => source_text.to_s,
      "customer" => candidates["customer"].presence || customer&.name, "contact_name" => candidates["contact_name"],
      "contact_email" => candidates["contact_email"], "currency" => candidates["currency"],
      "products" => candidates["products"] || [], "questions" => [],
      "commercial_terms" => { "incoterm" => candidates["incoterm"], "destination" => candidates["destination"],
        "delivery" => candidates["delivery"], "packing" => candidates["packing"], "payment_terms" => candidates["payment_terms"] }.compact,
      "evidence" => { "customer" => candidates["customer"], "contact_name" => candidates["contact_name"],
        "contact_email" => candidates["contact_email"], "incoterm" => candidates["incoterm"], "destination" => candidates["destination"],
        "delivery" => candidates["delivery"], "packing" => candidates["packing"], "payment_terms" => candidates["payment_terms"] }.compact,
      "warnings" => []
    }.tap { |data| data["task_context"] = task_context if task_context.present? }
    self.field_states = { "customer" => extracted_data["customer"].present? ? "uncertain" : "missing",
      "products" => candidates["products"].present? ? "uncertain" : "missing", "price" => "missing", "freight" => "missing" }
    self.status = "review"
    save!
  end

  def extract_requirements!
    task_context = extracted_data.to_h["task_context"]
    analysis_source = source_type == "chat" ? InquiryAiContextBuilder.new(self).call : source_text
    data = InquiryAiExtractor.new(inquiry: self).extract(source_text: analysis_source, source_type: source_type)
    terms = data["commercial_terms"]
    self.extracted_data = data.merge("raw_requirements" => source_text.to_s).tap do |result|
      result["task_context"] = task_context if task_context.present?
    end
    self.field_states = {
      "customer" => data["customer"].present? ? "confirmed" : "missing",
      "products" => data["products"].any? ? "uncertain" : "missing",
      "price" => "missing",
      "freight" => terms["incoterm"].present? && terms["destination"].present? ? "uncertain" : "missing"
    }
    self.status = "review"
    save!
  end

  def catalog_matches
    InquiryCatalogMatcher.new(self).call
  end

  def ready_to_build_quote?
    products = Array(extracted_data["products"])
    extracted_data["customer"].present? && extracted_data["currency"].present? && products.any? &&
      products.all? { |product| product["name"].present? && product["quantity"].to_d.positive? }
  end

  def conversation_source
    messages = inquiry_messages.filter_map do |message|
      next if message.body.blank?

      captured = message.chat_captured_message
      role = { "buyer" => "customer", "seller" => "our_sales", "internal" => "other" }.fetch(message.direction)
      message_id = captured&.platform_message_id.presence || "local-#{message.id}"
      type = captured&.message_type.presence || (message.attachment.attached? ? "file" : "text")
      sender = captured&.sender_name.presence
      header = [ "message_id=#{message_id}", "role=#{role}", "type=#{type}",
        "channel=#{message.channel}", "sent_at=#{message.occurred_at.iso8601}", ("sender=#{sender}" if sender) ].compact.join(" | ")
      "[#{header}]\n#{message.body.to_s.squish}"
    end
    messages.presence&.join("\n\n") || source_text.to_s
  end
end
