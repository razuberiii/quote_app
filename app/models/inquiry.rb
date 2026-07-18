class Inquiry < ApplicationRecord
  FIELD_STATES = %w[confirmed matched uncertain missing conflict].freeze
  belongs_to :company
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_one_attached :source_file
  has_one :quote, dependent: :nullify
  validates :source_type, inclusion: { in: %w[email chat text excel csv pdf image manual] }

  def manually_extract!
    candidates = InquiryDeterministicParser.new(source_text).call
    self.extracted_data = {
      "raw_requirements" => source_text.to_s,
      "customer" => candidates["customer"], "contact_name" => candidates["contact_name"],
      "contact_email" => candidates["contact_email"], "currency" => candidates["currency"],
      "products" => candidates["products"] || [], "questions" => [],
      "commercial_terms" => { "incoterm" => candidates["incoterm"], "destination" => candidates["destination"] }.compact,
      "evidence" => { "customer" => candidates["customer"], "contact_name" => candidates["contact_name"],
        "contact_email" => candidates["contact_email"], "incoterm" => candidates["incoterm"], "destination" => candidates["destination"] }.compact,
      "warnings" => [ "AI 未完成，本页显示确定性识别候选；请逐项确认。" ]
    }
    self.field_states = { "customer" => candidates["customer"].present? ? "uncertain" : "missing",
      "products" => candidates["products"].present? ? "uncertain" : "missing", "price" => "missing", "freight" => "missing" }
    self.status = "review"
    save!
  end

  def extract_requirements!
    data = InquiryAiExtractor.new(inquiry: self).extract(source_text: source_text, source_type: source_type)
    terms = data["commercial_terms"]
    self.extracted_data = data.merge("raw_requirements" => source_text.to_s)
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
end
