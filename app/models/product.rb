class Product < ApplicationRecord
  require "cgi"

  PRICE_CURRENCIES = %w[USD EUR GBP CNY JPY AUD CAD SGD HKD].freeze

  belongs_to :company
  has_many :quote_items, dependent: :nullify
  has_one_attached :image
  has_many_attached :gallery_images

  before_validation :normalize_sku

  validates :name, presence: true
  validates :sku, presence: true
  validates :price_currency, presence: true, inclusion: { in: PRICE_CURRENCIES }
  validates :default_price, presence: true, numericality: { greater_than: 0 }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :moq, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_blank: true
  validate :sku_must_be_unique_within_company
  validate :default_specification_must_be_key_value, if: -> { new_record? || will_save_change_to_default_specification? }

  scope :by_company, ->(company_id) { where(company_id: company_id) }

  def display_image
    image.attached? ? image : gallery_images.first
  end

  def ensure_display_image!
    return if image.attached?

    fallback = gallery_images.attachments.first
    image.attach(fallback.blob) if fallback
  end

  private

  def normalize_sku
    self.sku = sku.to_s.strip.upcase.presence
    self.price_currency = price_currency.to_s.upcase.presence || "USD"
    self.unit = unit.to_s.strip.presence
    self.lead_time = lead_time.to_s.strip.presence
    self.product_category = product_category.to_s.strip.presence
    normalized_spec = CGI.unescapeHTML(default_specification.to_s)
      .gsub(/&#10;|&#x0a;|&#13;|&#x0d;/i, "\n")
      .gsub(/\r\n?/, "\n")
      .strip
    self.default_specification = normalized_spec.presence
  end

  def sku_must_be_unique_within_company
    return if sku.blank? || company_id.blank?

    duplicate_exists = self.class
      .where(company_id: company_id)
      .where.not(id: id)
      .where("LOWER(TRIM(sku)) = ?", sku.downcase)
      .exists?

    errors.add(:sku, "already exists in your product list") if duplicate_exists
  end

  def default_specification_must_be_key_value
    return if default_specification.blank?

    invalid_line = default_specification
      .to_s
      .split(/\r?\n/)
      .map(&:strip)
      .reject(&:blank?)
      .find do |line|
        key, value = line.split(/[:=：]/, 2).map { |part| part.to_s.strip }
        key.blank? || value.blank?
      end

    return if invalid_line.blank?

    errors.add(:default_specification, "must use one pair per line with key/value separated by :, =, or ： (e.g. Power: 5kW)")
  end
end
