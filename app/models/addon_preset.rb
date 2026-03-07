class AddonPreset < ApplicationRecord
  belongs_to :company
  has_many :product_addon_presets, dependent: :destroy
  has_many :products, through: :product_addon_presets

  attr_writer :entries_text

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validate :entries_must_be_valid

  before_validation :normalize_entries

  scope :ordered, -> { order(:name, :created_at) }

  def normalized_entries
    normalize_rows(entries)
  end

  def entries_text
    return @entries_text if defined?(@entries_text)

    normalized_entries.map { |entry| "#{entry[:name]}: #{entry[:price]}" }.join("\n")
  end

  def entries_text=(value)
    @entries_text = value.to_s
    self.entries = parse_entries_text(value)
  end

  def as_payload
    {
      id: id,
      name: name,
      entries: normalized_entries
    }
  end

  private

  def normalize_entries
    self.entries = normalize_rows(entries)
  end

  def entries_must_be_valid
    return if normalized_entries.any?

    errors.add(:entries, "must include at least one add-on")
  end

  def normalize_rows(raw)
    Array(raw).filter_map do |entry|
      next unless entry.is_a?(Hash)

      name = entry["name"].presence || entry[:name].presence
      price = entry["price"].presence || entry[:price].presence || entry["amount"].presence || entry[:amount].presence
      next if name.blank? || price.blank?

      parsed_price = BigDecimal(price.to_s)
      next if parsed_price.negative?

      { name: name.to_s.strip, price: parsed_price.round(2).to_s("F") }
    rescue ArgumentError
      next
    end
  end

  def parse_entries_text(value)
    value.to_s.lines.filter_map do |line|
      text = line.to_s.strip
      next if text.blank?

      name, amount_text = text.split(/[:=：]/, 2).map { |part| part.to_s.strip }
      next if name.blank? || amount_text.blank?

      amount = BigDecimal(amount_text)
      next if amount.negative?

      { name: name, price: amount.round(2).to_s("F") }
    rescue ArgumentError
      next
    end
  end
end
