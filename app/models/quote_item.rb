class QuoteItem < ApplicationRecord
  PRICE_SOURCES = %w[unpriced catalog quantity_tier customer_specific configuration_rule historical_quote manual].freeze
  SELECTION_MODES = %w[fixed selectable request_only].freeze
  MAX_DECIMAL_15_4 = BigDecimal("99999999999.9999")
  MAX_DESCRIPTION_LENGTH = 1000
  MAX_SPEC_ROWS = 40
  MAX_SPEC_KEY_LENGTH = 120
  MAX_SPEC_VALUE_LENGTH = 500
  MAX_ADDON_ROWS = 40
  MAX_ADDON_NAME_LENGTH = 180
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 8.megabytes
  IMAGE_SOURCES = %w[none product_gallery manual_upload].freeze
  ITEM_TYPES = %w[
    product_main
    fee_shipping
    fee_packing
    fee_dangerous_goods
    fee_port_service
    fee_custom
  ].freeze
  FEE_ITEM_TYPES = ITEM_TYPES - [ "product_main" ]

  belongs_to :quote
  belongs_to :product, optional: true
  has_one_attached :item_image

  attr_writer :specifications_text, :addon_charges_text
  attr_accessor :item_image_blob_id, :remove_item_image

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :image_source, inclusion: { in: IMAGE_SOURCES }
  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :price_source, inclusion: { in: PRICE_SOURCES }, if: -> { has_attribute?(:price_source) }
  validates :selection_mode, inclusion: { in: SELECTION_MODES }, if: -> { has_attribute?(:selection_mode) }
  validate :validate_addon_charge_amounts
  validate :description_length_within_limit
  validate :specifications_within_limits
  validate :addons_within_limits
  validate :product_company_matches_quote_company
  validate :snapshots_locked_after_quote_sent
  validate :monetary_values_fit_storage_precision
  validate :item_image_constraints

  before_validation :apply_product_defaults
  before_validation :ensure_item_type
  before_validation :sanitize_fee_item_media
  before_validation :apply_item_image_selection
  before_validation :normalize_structured_fields
  before_validation :calculate_amount
  after_commit :refresh_related_product_stats

  scope :ordered,     -> {
    order(Arel.sql("CASE WHEN item_type = 'product_main' THEN 0 ELSE 1 END ASC"), created_at: :asc)
  }
  scope :with_product, -> { where.not(product_id: nil) }
  scope :in_period,    ->(days) { joins(:quote).where(quotes: { created_at: days.days.ago..Time.current }) }

  def line_total
    amount.presence || (unit_price.to_d * quantity.to_i + addon_total).round(2)
  end

  def effective_image_attachment
    return item_image if item_image.attached?
    return nil unless product

    product.display_image
  end

  def addon_total
    addon_charge_entries.sum { |entry| entry[:amount].to_d }.round(2)
  end

  def fee_item?
    FEE_ITEM_TYPES.include?(item_type.to_s)
  end

  def specification_pairs
    source = self[:spec_snapshot].presence || self[:specifications]
    normalize_specifications(source)
  end

  def addon_charge_entries
    source = self[:addon_snapshot].presence || self[:addon_charges]
    normalize_addon_charges(source)
  end

  def specifications_text
    return @specifications_text if defined?(@specifications_text)

    specification_pairs.map { |pair| "#{pair[:key]}: #{pair[:value]}" }.join("\n")
  end

  def specifications_text=(value)
    @specifications_text = value.to_s
    parsed = parse_specifications_text(value)
    self[:specifications] = parsed
    self[:spec_snapshot] = parsed
  end

  def addon_charges_text
    return @addon_charges_text if defined?(@addon_charges_text)

    addon_charge_entries.map { |entry| "#{entry[:name]}: #{format('%.2f', entry[:amount].to_d)}" }.join("\n")
  end

  def addon_charges_text=(value)
    @addon_charges_text = value.to_s
    parsed = parse_addon_charges_text(value)
    self[:addon_charges] = parsed
    self[:addon_snapshot] = parsed
  end

  private

  def apply_product_defaults
    return unless product

    self.description = product.name if description.blank?
    self.unit_price = product.default_price if unit_price.blank?
    apply_default_configuration_from_product
  end

  def ensure_item_type
    self.item_type = "product_main" if item_type.blank?
  end

  def calculate_amount
    return if unit_price.blank? || quantity.blank?

    self.amount = (unit_price.to_d * quantity.to_i + addon_total).round(2)
  end

  def sanitize_fee_item_media
    return unless fee_item?

    item_image.detach if item_image.attached?
    self.item_image_blob_id = nil
    self.remove_item_image = "1"
    self.image_source = "none"
  end

  def normalize_structured_fields
    normalized_specs = normalize_specifications(self[:spec_snapshot].presence || self[:specifications])
    normalized_addons = normalize_addon_charges(self[:addon_snapshot].presence || self[:addon_charges])
    self[:spec_snapshot] = normalized_specs
    self[:addon_snapshot] = normalized_addons
    self[:specifications] = normalized_specs
    self[:addon_charges] = normalized_addons
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

  def apply_default_configuration_from_product
    # Keep page-edited values as source of truth for existing quote items.
    # Product defaults should only seed brand-new rows.
    return unless new_record?

    if specification_pairs.blank?
      defaults = product.effective_default_specs.map { |entry| { key: entry[:name], value: entry[:value] } }
      self[:spec_snapshot] = defaults if defaults.present?
      self[:specifications] = defaults if defaults.present?
    end

    return unless addon_charge_entries.blank?

    defaults = product.effective_default_addons.map { |entry| { name: entry[:name], amount: entry[:price] } }
    self[:addon_snapshot] = defaults if defaults.present?
    self[:addon_charges] = defaults if defaults.present?
  end

  def apply_item_image_selection
    if ActiveModel::Type::Boolean.new.cast(remove_item_image)
      item_image.detach if item_image.attached?
      self.image_source = "none"
      return
    end

    return if item_image_blob_id.blank?

    blob = ActiveStorage::Blob.find_by(id: item_image_blob_id)
    return if blob.blank?
    return unless allowed_product_gallery_blob?(blob)

    item_image.attach(blob)
    self.image_source = "product_gallery"
  end

  def allowed_product_gallery_blob?(blob)
    return false if product.blank?

    ActiveStorage::Attachment.where(blob_id: blob.id, record_type: "Product", record_id: product.id)
      .where(name: [ "image", "gallery_images" ])
      .exists?
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

  def description_length_within_limit
    return if description.blank?
    return if description.length <= MAX_DESCRIPTION_LENGTH

    errors.add(:description, "is too long (maximum is #{MAX_DESCRIPTION_LENGTH} characters)")
  end

  def specifications_within_limits
    rows = specification_pairs
    if rows.length > MAX_SPEC_ROWS
      errors.add(:specifications, "can include up to #{MAX_SPEC_ROWS} rows")
      return
    end

    rows.each do |pair|
      if pair[:key].to_s.length > MAX_SPEC_KEY_LENGTH
        errors.add(:specifications, "key is too long (maximum is #{MAX_SPEC_KEY_LENGTH} characters)")
        break
      end
      if pair[:value].to_s.length > MAX_SPEC_VALUE_LENGTH
        errors.add(:specifications, "value is too long (maximum is #{MAX_SPEC_VALUE_LENGTH} characters)")
        break
      end
    end
  end

  def addons_within_limits
    rows = addon_charge_entries
    if rows.length > MAX_ADDON_ROWS
      errors.add(:addon_charges, "can include up to #{MAX_ADDON_ROWS} rows")
      return
    end

    rows.each do |entry|
      if entry[:name].to_s.length > MAX_ADDON_NAME_LENGTH
        errors.add(:addon_charges, "name is too long (maximum is #{MAX_ADDON_NAME_LENGTH} characters)")
        break
      end
    end
  end

  def monetary_values_fit_storage_precision
    if unit_price.present? && unit_price.to_d > MAX_DECIMAL_15_4
      errors.add(:unit_price, "is too large")
    end

    if amount.present? && amount.to_d > MAX_DECIMAL_15_4
      errors.add(:base, "Line total is too large for storage. Reduce quantity, unit price, or add-ons.")
    end

    if addon_total > MAX_DECIMAL_15_4
      errors.add(:addon_charges, "total is too large")
    end
  end

  def product_company_matches_quote_company
    return if product.blank? || quote.blank?
    return if product.company_id == quote.company_id

    errors.add(:product, "must belong to the same company as the quote")
  end

  def snapshots_locked_after_quote_sent
    return unless persisted?
    return if quote.blank? || quote.draft?

    if will_save_change_to_spec_snapshot? || will_save_change_to_addon_snapshot? || will_save_change_to_specifications? || will_save_change_to_addon_charges? || will_save_change_to_image_source?
      errors.add(:base, "Specifications and add-ons are locked once the quote is sent")
    end
  end

  def item_image_constraints
    return unless item_image.attached?

    blob = item_image.blob
    if !IMAGE_CONTENT_TYPES.include?(blob.content_type.to_s)
      errors.add(:item_image, "must be PNG, JPG, WEBP, or GIF")
    end
    if blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:item_image, "must be smaller than #{MAX_IMAGE_SIZE / 1.megabyte}MB")
    end

    if image_source.to_s == "none"
      self.image_source = "manual_upload"
    end
  end

  def refresh_related_product_stats
    product_ids = [ product_id_previously_was, product_id ].compact.uniq
    ProductIntelligenceRefresher.refresh_products(product_ids)
  end
end
