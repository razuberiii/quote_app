class SpecPreset < ApplicationRecord
  belongs_to :company
  has_many :product_spec_presets, dependent: :destroy
  has_many :products, through: :product_spec_presets

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

    normalized_entries.map { |entry| "#{entry[:name]}: #{entry[:value]}" }.join("\n")
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

    errors.add(:entries, "must include at least one specification")
  end

  def normalize_rows(raw)
    Array(raw).filter_map do |entry|
      next unless entry.is_a?(Hash)

      name = entry["name"].presence || entry[:name].presence || entry["key"].presence || entry[:key].presence
      value = entry["value"].presence || entry[:value].presence
      next if name.blank? || value.blank?

      { name: name.to_s.strip, value: value.to_s.strip }
    end
  end

  def parse_entries_text(value)
    value.to_s.lines.filter_map do |line|
      text = line.to_s.strip
      next if text.blank?

      name, val = text.split(/[:=：]/, 2).map { |part| part.to_s.strip }
      next if name.blank? || val.blank?

      { name: name, value: val }
    end
  end
end
