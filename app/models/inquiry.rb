class Inquiry < ApplicationRecord
  FIELD_STATES = %w[confirmed matched uncertain missing conflict].freeze
  belongs_to :company
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  validates :source_type, inclusion: { in: %w[email chat text excel pdf manual] }

  def manually_extract!
    self.extracted_data = { "raw_requirements" => source_text.to_s, "products" => [], "questions" => [] }
    self.field_states = { "customer" => "missing", "products" => "missing", "price" => "missing", "freight" => "missing" }
    self.status = "review"
    save!
  end
end
