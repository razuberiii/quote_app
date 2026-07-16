class QuotePreset < ApplicationRecord
  MODULE_KEYS = %w[
    business_terms
    advanced_trade_terms
    advanced_logistics
    standard_fee_items
    container_loading
    configuration_block
    formal_closing
  ].freeze
  MAX_NAME_LENGTH = 120
  MAX_HEADER_LENGTH = 40
  MAX_FEE_ITEM_ROWS = 30
  MAX_FEE_ITEM_NAME_LENGTH = 240
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif image/svg+xml].freeze
  MAX_SIGNATURE_IMAGE_SIZE = 5.megabytes

  belongs_to :company
  has_one_attached :seller_signature_image
  has_one_attached :seller_stamp_image

  validates :module_key, presence: true, inclusion: { in: MODULE_KEYS }
  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }, uniqueness: { scope: [ :company_id, :module_key ] }
  validates :position, numericality: { only_integer: true }
  validate :payload_must_be_hash
  validate :payload_shape_must_be_valid
  validate :module_limit_within_plan
  validate :seller_signature_image_constraints
  validate :seller_stamp_image_constraints

  before_validation :normalize_payload

  scope :ordered, -> { order(:module_key, :position, :name, :created_at) }

  def payload_data
    payload.is_a?(Hash) ? payload : {}
  end

  def duplicated_name
    "#{name} Copy"
  end

  private

  def payload_must_be_hash
    return if payload.is_a?(Hash)

    errors.add(:payload, "must be a JSON object")
  end

  def payload_shape_must_be_valid
    return unless payload.is_a?(Hash)

    case module_key
    when "business_terms"
      validate_business_terms_payload
    when "advanced_trade_terms"
      validate_hash_with_keys(Quote::ADVANCED_TRADE_TERMS_KEYS)
    when "advanced_logistics"
      validate_hash_with_keys(Quote::ADVANCED_LOGISTICS_KEYS)
    when "standard_fee_items"
      validate_standard_fee_items_payload
    when "configuration_block"
      validate_configuration_payload
    when "container_loading"
      validate_container_loading_payload
    when "formal_closing"
      validate_formal_closing_payload
    end
  end

  def validate_business_terms_payload
    allowed = Quote::BUSINESS_PRESET_KEYS
    unknown = payload_data.keys.map(&:to_s) - allowed
    errors.add(:payload, "contains unsupported keys: #{unknown.join(', ')}") if unknown.any?
  end

  def validate_hash_with_keys(allowed_keys)
    unknown = payload_data.keys.map(&:to_s) - allowed_keys
    errors.add(:payload, "contains unsupported keys: #{unknown.join(', ')}") if unknown.any?
  end

  def validate_configuration_payload
    rows = rows_from_payload(payload_data["rows"])
    if rows.size > Quote::MAX_CONFIGURATION_BLOCK_ROWS
      errors.add(:payload, "configuration rows exceed limit (#{Quote::MAX_CONFIGURATION_BLOCK_ROWS})")
    end
  end

  def validate_standard_fee_items_payload
    allowed = %w[rows]
    unknown = payload_data.keys.map(&:to_s) - allowed
    errors.add(:payload, "contains unsupported keys: #{unknown.join(', ')}") if unknown.any?

    rows = rows_from_payload(payload_data["rows"])
    if rows.size > MAX_FEE_ITEM_ROWS
      errors.add(:payload, "fee item rows exceed limit (#{MAX_FEE_ITEM_ROWS})")
      return
    end

    rows.each do |row|
      next unless row.is_a?(Hash)

      name = row["name"].to_s.squish
      if name.length > MAX_FEE_ITEM_NAME_LENGTH
        errors.add(:payload, "fee item name is too long (max #{MAX_FEE_ITEM_NAME_LENGTH})")
        break
      end

      quantity = row["quantity"].to_i
      if quantity.negative?
        errors.add(:payload, "fee item quantity must be 0 or greater")
        break
      end

      unit_price = begin
        BigDecimal(row["unit_price"].to_s)
      rescue ArgumentError
        nil
      end
      if unit_price.nil? || unit_price.negative?
        errors.add(:payload, "fee item unit price must be 0 or greater")
        break
      end
    end
  end

  def validate_container_loading_payload
    headers = payload_data["headers"].is_a?(Hash) ? payload_data["headers"] : {}
    %w[variant container_type capacity note].each do |key|
      value = headers[key].to_s.squish
      next if value.blank?
      next if value.length <= MAX_HEADER_LENGTH

      errors.add(:payload, "container header '#{key}' is too long (max #{MAX_HEADER_LENGTH})")
      break
    end

    rows = rows_from_payload(payload_data["rows"])
    if rows.size > Quote::MAX_CONTAINER_LOADING_ROWS
      errors.add(:payload, "container rows exceed limit (#{Quote::MAX_CONTAINER_LOADING_ROWS})")
    end
  end

  def validate_formal_closing_payload
    allowed = %w[
      pi_number
      payment_term
      trade_term
      delivery_time
      bank_route
      beneficiary_details
      remittance_note
      buyer_signature_line_enabled
    ]
    unknown = payload_data.keys.map(&:to_s) - allowed
    errors.add(:payload, "contains unsupported keys: #{unknown.join(', ')}") if unknown.any?
  end

  def normalize_payload
    source = payload.is_a?(Hash) ? payload.deep_dup : {}
    normalized =
      case module_key
      when "business_terms"
        Quote::BUSINESS_PRESET_KEYS.index_with { |key| source[key].to_s.squish.presence }.compact
      when "advanced_trade_terms"
        Quote::ADVANCED_TRADE_TERMS_KEYS.index_with { |key| source[key].to_s.squish.presence }.compact
      when "advanced_logistics"
        Quote::ADVANCED_LOGISTICS_KEYS.index_with { |key| source[key].to_s.squish.presence }.compact
      when "standard_fee_items"
        {
          "rows" => rows_from_payload(source["rows"]).filter_map do |row|
            next unless row.is_a?(Hash)

            name = row["name"].to_s.squish
            unit_price = begin
              BigDecimal(row["unit_price"].to_s).round(2)
            rescue ArgumentError
              nil
            end
            quantity = row["quantity"].to_i
            next if name.blank?
            next if unit_price.blank? || unit_price.negative?
            next if quantity <= 0

            {
              "name" => name.first(MAX_FEE_ITEM_NAME_LENGTH),
              "unit_price" => unit_price.to_s("F"),
              "quantity" => quantity,
              "position" => row["position"].to_i
            }
          end
        }
      when "configuration_block"
        {
          "rows" => rows_from_payload(source["rows"]).filter_map do |row|
            next unless row.is_a?(Hash)

            label = row["label"].to_s.squish
            value = row["value"].to_s.squish
            next if label.blank? || value.blank?

            {
              "label" => label,
              "value" => value,
              "position" => row["position"].to_i
            }
          end
        }
      when "container_loading"
        headers = source["headers"].is_a?(Hash) ? source["headers"] : {}
        {
          "headers" => {
            "variant" => (headers["variant"].to_s.squish.presence || "Variant / Version").first(MAX_HEADER_LENGTH),
            "container_type" => (headers["container_type"].to_s.squish.presence || "Container Type").first(MAX_HEADER_LENGTH),
            "capacity" => (headers["capacity"].to_s.squish.presence || "Capacity").first(MAX_HEADER_LENGTH),
            "note" => (headers["note"].to_s.squish.presence || "Note").first(MAX_HEADER_LENGTH)
          },
          "note_enabled" => if source.key?("note_enabled")
            ActiveModel::Type::Boolean.new.cast(source["note_enabled"])
                            else
            true
                            end,
          "rows" => rows_from_payload(source["rows"]).filter_map do |row|
            next unless row.is_a?(Hash)

            variant = row["variant"].to_s.squish
            container_type = row["container_type"].to_s.squish
            capacity = row["capacity"].to_s.squish
            note = row["note"].to_s.squish
            next if variant.blank? && container_type.blank? && capacity.blank? && note.blank?

            {
              "variant" => variant,
              "container_type" => container_type,
              "capacity" => capacity,
              "note" => note,
              "position" => row["position"].to_i
            }
          end
        }
      when "formal_closing"
        fields = %w[
          pi_number
          payment_term
          trade_term
          delivery_time
          bank_route
          beneficiary_details
          remittance_note
        ].index_with { |key| source[key].to_s.squish.presence }.compact
        fields.merge(
          "buyer_signature_line_enabled" => ActiveModel::Type::Boolean.new.cast(source["buyer_signature_line_enabled"])
        )
      else
        {}
      end
    self.payload = normalized
  end

  def rows_from_payload(raw_rows)
    if raw_rows.is_a?(Array)
      raw_rows
    elsif raw_rows.is_a?(Hash)
      raw_rows.values
    else
      []
    end
  end

  def module_limit_within_plan
    return if company.blank?
    return unless new_record? || will_save_change_to_module_key?

    module_name = module_key.to_s
    return if module_name.blank?

    existing = company.quote_presets.where(module_key: module_name)
    existing = existing.where.not(id: id) if persisted?
    limit = company.quote_preset_limit_per_module
    return if existing.count < limit

    errors.add(:base, I18n.t("quote_presets.flash.module_limit_reached", module: module_name.humanize, limit: limit, default: "Preset limit reached for this module (%{limit})."))
  end

  def seller_signature_image_constraints
    validate_image_attachment_constraints(:seller_signature_image)
  end

  def seller_stamp_image_constraints
    validate_image_attachment_constraints(:seller_stamp_image)
  end

  def validate_image_attachment_constraints(name)
    attachment = public_send(name)
    return unless attachment.attached?

    if !IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)
      errors.add(name, "must be an image (PNG, JPG, WEBP, GIF, or SVG)")
    end
    if attachment.blob.byte_size > MAX_SIGNATURE_IMAGE_SIZE
      errors.add(name, "must be smaller than #{MAX_SIGNATURE_IMAGE_SIZE / 1.megabyte}MB")
    end
  end
end
