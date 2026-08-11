class WorkbookTemplate < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes
  CELL_REFERENCE = /\A[A-Z]{1,3}[1-9]\d{0,5}\z/
  CORE_FIELDS = %w[
    quote_number issued_on valid_until seller_name seller_address customer_name customer_contact
    customer_address currency subtotal shipping discount tax total payment_term trade_term delivery_notes
  ].freeze
  ITEM_FIELDS = %w[sku description specifications quantity unit unit_price discount amount].freeze
  CUSTOM_FIELD_TYPES = %w[text number date multiline].freeze

  belongs_to :company
  has_many :quotes, dependent: :restrict_with_error
  has_one_attached :workbook

  validates :name, presence: true, length: { maximum: 120 }
  validate :workbook_is_xlsx
  validate :mapping_references_are_valid
  validate :custom_field_definitions_are_valid

  def custom_field_definitions
    Array(custom_fields).map(&:with_indifferent_access)
  end

  private

  def workbook_is_xlsx
    return errors.add(:workbook, "is required") unless workbook.attached?
    errors.add(:workbook, "must be an .xlsx file") unless workbook.filename.extension.to_s.downcase == "xlsx"
    errors.add(:workbook, "must be 10 MB or smaller") if workbook.byte_size > MAX_FILE_SIZE
  end

  def mapping_references_are_valid
    field_mappings.to_h.each_value { |cell| validate_cell(cell) }
    start_row = item_mapping.to_h["start_row"].to_i
    errors.add(:item_mapping, "start row must be positive") if item_mapping.present? && start_row < 1
    item_mapping.to_h.fetch("columns", {}).each_value { |column| validate_cell("#{column}1") }
  end

  def custom_field_definitions_are_valid
    keys = custom_field_definitions.map { |field| field[:key].to_s }
    errors.add(:custom_fields, "contain duplicate keys") if keys.uniq.size != keys.size
    custom_field_definitions.each do |field|
      errors.add(:custom_fields, "need a key, label, and cell") if field.values_at(:key, :label, :cell).any?(&:blank?)
      errors.add(:custom_fields, "have an unsupported type") unless field[:type].to_s.presence_in(CUSTOM_FIELD_TYPES) || field[:type].blank?
      validate_cell(field[:cell]) if field[:cell].present?
    end
  end

  def validate_cell(value)
    errors.add(:base, "Invalid cell reference: #{value}") unless value.to_s.upcase.match?(CELL_REFERENCE)
  end
end
