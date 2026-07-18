class Product < ApplicationRecord
  alias_attribute :currency, :price_currency
  alias_attribute :base_price, :default_price
  require "cgi"

  PRICE_CURRENCIES = %w[USD EUR GBP CNY JPY AUD CAD SGD HKD MXN BRL COP CLP PEN ARS].freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 8.megabytes
  MAX_GALLERY_IMAGES = 12
  MAX_GALLERY_UPLOAD_PER_REQUEST = 6

  belongs_to :company
  has_many :quote_items, dependent: :nullify
  has_many :product_spec_presets, dependent: :destroy
  has_many :spec_presets, through: :product_spec_presets
  has_many :product_addon_presets, dependent: :destroy
  has_many :addon_presets, through: :product_addon_presets
  belongs_to :default_spec_preset, class_name: "SpecPreset", optional: true
  belongs_to :default_addon_preset, class_name: "AddonPreset", optional: true
  has_one_attached :image
  has_many_attached :gallery_images

  before_validation :normalize_sku
  before_validation :normalize_configurator_fields

  validates :name, presence: true
  validates :price_currency, presence: true, inclusion: { in: PRICE_CURRENCIES }
  validates :default_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :moq, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_blank: true
  validate :sku_must_be_unique_within_company
  validate :default_specification_must_be_key_value, if: -> { new_record? || will_save_change_to_default_specification? }
  validate :default_specs_must_be_valid
  validate :default_addons_must_be_valid
  validate :default_spec_preset_belongs_to_product
  validate :default_addon_preset_belongs_to_product
  validate :image_must_be_valid
  validate :gallery_images_constraints

  scope :by_company, ->(company_id) { where(company_id: company_id) }

  def display_image
    image.attached? ? image : gallery_images.first
  end

  def ensure_display_image!
    return if image.attached?

    fallback = gallery_images.attachments.first
    image.attach(fallback.blob) if fallback
  end

  def effective_default_specs
    configured = default_spec_preset&.normalized_entries || normalize_default_specs(default_specs)
    return configured if configured.present?

    parse_legacy_default_specification(default_specification)
  end

  def effective_default_addons
    default_addon_preset&.normalized_entries || normalize_default_addons(default_addons)
  end

  def available_spec_preset_payloads
    presets = company.spec_presets.where(id: spec_preset_ids).ordered.map(&:as_payload)
    if presets.blank? && normalize_default_specs(default_specs).present?
      presets << { id: "legacy", name: "Legacy Default", entries: normalize_default_specs(default_specs) }
    end
    presets
  end

  def available_addon_preset_payloads
    presets = company.addon_presets.where(id: addon_preset_ids).ordered.map(&:as_payload)
    if presets.blank? && normalize_default_addons(default_addons).present?
      presets << { id: "legacy", name: "Legacy Default", entries: normalize_default_addons(default_addons) }
    end
    presets
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

  def normalize_configurator_fields
    normalized_specs = default_spec_preset&.normalized_entries || normalize_default_specs(default_specs)
    normalized_specs = parse_legacy_default_specification(default_specification) if normalized_specs.blank?
    self.default_specs = normalized_specs
    self.default_specification = normalized_specs.map { |entry| "#{entry[:name]}: #{entry[:value]}" }.join("\n").presence

    normalized_addons = default_addon_preset&.normalized_entries || normalize_default_addons(default_addons)
    self.default_addons = normalized_addons
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

  def default_specs_must_be_valid
    rows = normalize_default_specs(default_specs)
    return if rows.all? { |entry| entry[:name].present? && entry[:value].present? }

    errors.add(:default_specs, "must include a name and value for each specification")
  end

  def default_addons_must_be_valid
    rows = normalize_default_addons(default_addons)
    return if rows.all? { |entry| entry[:name].present? && entry[:price].to_d >= 0 }

    errors.add(:default_addons, "must include a name and non-negative price for each add-on")
  end

  def normalize_default_specs(raw)
    Array(raw).filter_map do |entry|
      next unless entry.is_a?(Hash)

      name = entry["name"].presence || entry[:name].presence
      value = entry["value"].presence || entry[:value].presence
      next if name.blank? && value.blank?

      { name: name.to_s.strip, value: value.to_s.strip }
    end
  end

  def normalize_default_addons(raw)
    Array(raw).filter_map do |entry|
      next unless entry.is_a?(Hash)

      name = entry["name"].presence || entry[:name].presence
      price = entry["price"].presence || entry[:price].presence || entry["amount"].presence || entry[:amount].presence
      next if name.blank? && price.blank?

      parsed_price = BigDecimal(price.to_s)
      next if parsed_price.negative?

      { name: name.to_s.strip, price: parsed_price.round(2).to_s("F") }
    rescue ArgumentError
      next
    end
  end

  def parse_legacy_default_specification(text)
    text.to_s.lines.filter_map do |line|
      content = line.to_s.strip
      next if content.blank?

      name, value = content.split(/[:=：]/, 2).map { |part| part.to_s.strip }
      next if name.blank? || value.blank?

      { name: name, value: value }
    end
  end

  def default_spec_preset_belongs_to_product
    return if default_spec_preset.blank?
    bound_ids = spec_preset_ids.map(&:to_i)
    return if default_spec_preset.company_id == company_id && bound_ids.include?(default_spec_preset_id)

    errors.add(:default_spec_preset, "must be one of the product's bound spec presets")
  end

  def default_addon_preset_belongs_to_product
    return if default_addon_preset.blank?
    bound_ids = addon_preset_ids.map(&:to_i)
    return if default_addon_preset.company_id == company_id && bound_ids.include?(default_addon_preset_id)

    errors.add(:default_addon_preset, "must be one of the product's bound add-on presets")
  end

  def image_must_be_valid
    return unless image.attached?

    if !IMAGE_CONTENT_TYPES.include?(image.blob.content_type)
      errors.add(:image, "must be PNG, JPG, WEBP, or GIF")
    end
    if image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:image, "must be smaller than #{MAX_IMAGE_SIZE / 1.megabyte}MB")
    end
  end

  def gallery_images_constraints
    return unless gallery_images.attached?

    if gallery_images.attachments.size > MAX_GALLERY_IMAGES
      errors.add(:gallery_images, "can have up to #{MAX_GALLERY_IMAGES} images")
    end

    gallery_images.each do |attachment|
      blob = attachment.blob
      if !IMAGE_CONTENT_TYPES.include?(blob.content_type)
        errors.add(:gallery_images, "must be PNG, JPG, WEBP, or GIF")
      end
      if blob.byte_size > MAX_IMAGE_SIZE
        errors.add(:gallery_images, "each image must be smaller than #{MAX_IMAGE_SIZE / 1.megabyte}MB")
      end
    end
  end
end
