class QuoteItem < ApplicationRecord
  belongs_to :quote
  belongs_to :product, optional: true

  attr_writer :specifications_text, :addon_charges_text

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :validate_addon_charge_amounts
  validate :product_company_matches_quote_company

  before_validation :apply_product_defaults
  before_validation :normalize_structured_fields
  before_validation :calculate_amount

  scope :ordered, -> { order(created_at: :asc) }

  def line_total
    amount.presence || (unit_price.to_d * quantity.to_i + addon_total).round(2)
  end

  def addon_total
    addon_charge_entries.sum { |entry| entry[:amount].to_d }.round(2)
  end

  def specification_pairs
    normalize_specifications(self[:specifications])
  end

  def addon_charge_entries
    normalize_addon_charges(self[:addon_charges])
  end

  def specifications_text
    return @specifications_text if defined?(@specifications_text)

    specification_pairs.map { |pair| "#{pair[:key]}: #{pair[:value]}" }.join("\n")
  end

  def specifications_text=(value)
    @specifications_text = value.to_s
    self[:specifications] = parse_specifications_text(value)
  end

  def addon_charges_text
    return @addon_charges_text if defined?(@addon_charges_text)

    addon_charge_entries.map { |entry| "#{entry[:name]}: #{format('%.2f', entry[:amount].to_d)}" }.join("\n")
  end

  def addon_charges_text=(value)
    @addon_charges_text = value.to_s
    self[:addon_charges] = parse_addon_charges_text(value)
  end

  private

  def apply_product_defaults
    return unless product

    self.description = product.name if description.blank?
    self.unit_price = product.default_price if unit_price.blank?
    apply_default_specification_from_product
  end

  def calculate_amount
    return if unit_price.blank? || quantity.blank?

    self.amount = (unit_price.to_d * quantity.to_i + addon_total).round(2)
  end

  def normalize_structured_fields
    self[:specifications] = normalize_specifications(self[:specifications])
    self[:addon_charges] = normalize_addon_charges(self[:addon_charges])
  end

  def normalize_specifications(raw)
    Array(raw).filter_map do |entry|
      key = entry.is_a?(Hash) ? entry["key"].presence || entry[:key].presence : nil
      value = entry.is_a?(Hash) ? entry["value"].presence || entry[:value].presence : nil
      next if key.blank? || value.blank?

      { key: key.to_s.strip, value: value.to_s.strip }
    end
  end

  def normalize_addon_charges(raw)
    Array(raw).filter_map do |entry|
      next unless entry.is_a?(Hash)

      name = entry["name"].presence || entry[:name].presence
      amount = entry["amount"].presence || entry[:amount].presence
      next if name.blank? || amount.blank?

      parsed = BigDecimal(amount.to_s)
      next if parsed.negative?

      { name: name.to_s.strip, amount: parsed.round(2).to_s("F") }
    rescue ArgumentError
      next
    end
  end

  def parse_specifications_text(value)
    value.to_s.lines.filter_map do |line|
      content = line.to_s.strip
      next if content.blank?

      key, val = content.split(/[:=：]/, 2).map { |part| part.to_s.strip }
      next if key.blank? || val.blank?

      { key: key, value: val }
    end
  end

  def apply_default_specification_from_product
    return if specification_pairs.present?
    return if product.default_specification.blank?

    parsed_default_specification = parse_specifications_text(product.default_specification)
    return if parsed_default_specification.blank?

    self[:specifications] = parsed_default_specification
  end

  def parse_addon_charges_text(value)
    value.to_s.lines.filter_map do |line|
      content = line.to_s.strip
      next if content.blank?

      name, amount_text = content.split(/[:=：]/, 2).map { |part| part.to_s.strip }
      next if name.blank? || amount_text.blank?

      amount = BigDecimal(amount_text)
      next if amount.negative?

      { name: name, amount: amount.round(2).to_s("F") }
    rescue ArgumentError
      next
    end
  end

  def validate_addon_charge_amounts
    return if addon_charge_entries.all? { |entry| entry[:amount].to_d >= 0 }

    errors.add(:addon_charges, "must be greater than or equal to 0")
  end

  def product_company_matches_quote_company
    return if product.blank? || quote.blank?
    return if product.company_id == quote.company_id

    errors.add(:product, "must belong to the same company as the quote")
  end
end
