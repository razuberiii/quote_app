class Quote < ApplicationRecord
  BUYER_LOCALES = %w[en zh-CN es-419].freeze
  REMINDER_COOLDOWN = 12.hours
  MAX_DECIMAL_15_4 = BigDecimal("99999999999.9999")
  MAX_QUOTE_ITEMS_COUNT = 200
  MAX_NOTES_LENGTH = 6000
  MAX_TERMS_TEXT_LENGTH = 12000
  MAX_LEGAL_DISCLAIMER_LENGTH = 8000
  MAX_DELIVERY_NOTES_LENGTH = 4000
  MAX_SCOPE_OF_SUPPLY_LENGTH = 4000
  MAX_CHANGES_REQUEST_MESSAGE_LENGTH = 2000
  MAX_TOTAL_TEXT_BUDGET = 120_000
  ADVANCED_TRADE_TERMS_KEYS = %w[
    hs_code
    warranty_scope_note
    support_scope_note
    validity_clause_note
    delivery_commitment_note
    payment_clause_note
  ].freeze
  ADVANCED_LOGISTICS_KEYS = %w[
    freight_note
    container_type
    shipping_scope_note
    container_loading_note
  ].freeze
  ADVANCED_VISIBILITY_KEYS = %w[
    show_trade_terms_advanced
    show_logistics_block
  ].freeze
  BUSINESS_PRESET_KEYS = %w[
    payment_term
    trade_term
    delivery_notes
    terms_text
    scope_of_supply
  ].freeze
  CONFIGURATION_BLOCK_ROW_SOURCES = %w[quote product fallback].freeze
  DETAIL_PICTURES_ITEM_SOURCES = %w[quote_upload product_gallery fallback].freeze
  MAX_CONFIGURATION_BLOCK_ROWS = 30
  MAX_DETAIL_PICTURES_ITEMS = 24
  MAX_CONTAINER_LOADING_ROWS = 12
  MAX_CONTAINER_LOADING_HEADER_LENGTH = 40
  MAX_CONFIGURATION_LABEL_LENGTH = 120
  MAX_CONFIGURATION_VALUE_LENGTH = 500
  MAX_CONFIGURATION_NOTES_LENGTH = 2000
  MAX_DETAIL_PICTURE_CAPTION_LENGTH = 180
  MAX_CONTAINER_LOADING_CELL_LENGTH = 240
  MAX_FORMAL_CLOSING_FIELD_LENGTH = 1200
  FORMAL_CLOSING_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif image/svg+xml].freeze
  MAX_FORMAL_CLOSING_IMAGE_SIZE = 5.megabytes
  CONTAINER_LOADING_VARIANT_PRESET_OPTIONS = [
    "14 seats without windows",
    "14 seats with windows",
    "17 seats without windows",
    "17 seats with windows"
  ].freeze
  CONTAINER_LOADING_TYPE_PRESET_OPTIONS = [
    "20GP",
    "40GP",
    "40HQ",
    "45HQ"
  ].freeze
  CONTAINER_LOADING_CAPACITY_PRESET_OPTIONS = [
    "1 unit",
    "2 units",
    "3 units",
    "4 units"
  ].freeze
  DEFAULT_CONTAINER_LOADING_HEADERS = {
    "variant" => "Variant / Version",
    "container_type" => "Container Type",
    "capacity" => "Capacity",
    "note" => "Note"
  }.freeze
  STATUSES = %w[draft ready sent viewed revision_requested negotiating accepted awaiting_deposit won lost cancelled expired archived pending].freeze
  OPEN_STATUSES = %w[draft ready sent viewed revision_requested negotiating accepted awaiting_deposit pending].freeze
  AUTO_VIEW_STATUSES = %w[draft ready sent pending].freeze
  WIN_REASONS = %w[
    price_accepted
    preferred_terms
    fast_response
    technical_fit
    buyer_relationship
    sample_approved
    other
  ].freeze
  LOSS_REASONS = %w[
    price_too_high
    competitor_selected
    budget_frozen
    timeline_missed
    no_response
    internal_hold
    other
  ].freeze
  STALLED_REASONS = %w[
    awaiting_buyer_reply
    awaiting_internal_review
    pricing_under_review
    spec_clarification
    sample_pending
    budget_timing
    procurement_delay
    no_next_step
    other
  ].freeze

  CURRENCY_SYMBOLS = {
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "CNY" => "¥",
    "JPY" => "¥",
    "AUD" => "A$",
    "CAD" => "C$",
    "SGD" => "S$",
    "HKD" => "HK$",
    "MXN" => "MX$",
    "BRL" => "R$",
    "COP" => "COP",
    "CLP" => "CLP",
    "PEN" => "S/",
    "ARS" => "ARS"
  }.freeze

  belongs_to :company
  validates :buyer_locale, inclusion: { in: BUYER_LOCALES }
  belongs_to :customer
  belongs_to :template, class_name: "QuoteTemplate", optional: true
  belongs_to :source_quote, class_name: "Quote", optional: true
  belongs_to :inquiry, optional: true
  has_many :derived_quotes, class_name: "Quote", foreign_key: :source_quote_id, dependent: :nullify
  has_many :customer_follow_up_events, dependent: :nullify
  has_many :quote_items, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
  has_many :quote_revisions, dependent: :restrict_with_exception
  has_one :quote_acceptance, dependent: :restrict_with_exception
  has_one :proforma_invoice, dependent: :restrict_with_exception
  has_many :buyer_activities, dependent: :restrict_with_exception
  has_many :version_deliveries, dependent: :restrict_with_exception
  has_many :deal_responses, dependent: :restrict_with_exception
  has_many :final_documents, dependent: :restrict_with_exception
  has_one_attached :seller_signature_image
  has_one_attached :seller_stamp_image
  accepts_nested_attributes_for :quote_items,
                                allow_destroy: true,
                                reject_if: lambda { |attrs|
                                  attrs["product_id"].blank? &&
                                    attrs["description"].blank? &&
                                    attrs["unit_price"].blank? &&
                                    attrs["quantity"].blank?
                                }

  before_create :generate_quote_no, :set_revision_number
  before_validation :normalize_status
  before_validation :apply_auto_expired_status
  before_validation :set_final_amount_from_grand_total_for_won
  before_validation :sync_status_transition_timestamps
  before_validation :set_defaults
  before_validation :normalize_advanced_blocks
  after_commit :refresh_related_product_stats, if: :saved_change_to_status?

  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :tax_amount, :shipping_amount, :discount_amount,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_blank: true
  validates :terms_text, length: { maximum: MAX_TERMS_TEXT_LENGTH }, allow_blank: true
  validates :legal_disclaimer, length: { maximum: MAX_LEGAL_DISCLAIMER_LENGTH }, allow_blank: true
  validates :delivery_notes, length: { maximum: MAX_DELIVERY_NOTES_LENGTH }, allow_blank: true
  validates :scope_of_supply, length: { maximum: MAX_SCOPE_OF_SUPPLY_LENGTH }, allow_blank: true
  validates :changes_request_message, length: { maximum: MAX_CHANGES_REQUEST_MESSAGE_LENGTH }, allow_blank: true
  validate :must_have_at_least_one_quote_item
  validate :quote_item_count_within_limit
  validate :discount_not_greater_than_subtotal
  validate :final_amount_required_for_won
  validate :loss_reason_required_for_lost
  validate :win_reason_required_for_won
  validate :custom_reason_details_required_for_other
  validate :reason_values_are_allowed
  validate :monetary_values_fit_storage_precision
  validate :grand_total_fits_storage_precision
  validate :valid_until_cannot_be_in_the_past
  validate :total_text_budget_within_limit
  validate :configuration_block_within_limit
  validate :detail_pictures_block_within_limit
  validate :configuration_block_value_lengths
  validate :detail_pictures_block_item_constraints
  validate :container_loading_block_within_limit
  validate :container_loading_block_value_lengths
  validate :formal_closing_block_value_lengths
  validate :seller_signature_image_constraints
  validate :seller_stamp_image_constraints
  validates :source_quote_id, uniqueness: true, allow_nil: true, if: -> { self.class.column_names.include?("source_quote_id") }

  scope :latest_versions, -> {
  select("DISTINCT ON (quote_no) *")
    .order(:quote_no, revision_number: :desc)
  }
  scope :not_archived, -> {
    scope = all
    scope = scope.where(archived_at: nil) if column_names.include?("archived_at")
    scope = scope.where(deleted_at: nil) if column_names.include?("deleted_at")
    scope
  }
  scope :excluding_pi_documents, -> {
    column_names.include?("source_quote_id") ? where(source_quote_id: nil) : all
  }

  scope :search, ->(query) {
    return all if query.blank?

    query = "%#{query}%"
    where("quote_no ILIKE ? OR currency ILIKE ?", query, query)
  }
  scope :recent_30_days, -> { where(created_at: 30.days.ago..Time.current) }
  scope :won_or_lost, -> { where(status: %w[won lost]) }

  def title
    custom_title.presence || quote_items.ordered.first&.description.presence || "Quotation #{quote_no}"
  end

  def display_amount
    negotiated? && final_amount.present? ? final_amount : grand_total
  end

  def display_win_reason
    return if win_reason.blank?
    return win_reason_detail if win_reason == "other" && win_reason_detail.present?

    self.class.reason_label_for(:win, win_reason, company: company)
  end

  def display_loss_reason
    return if loss_reason.blank?
    return loss_reason_detail if loss_reason == "other" && loss_reason_detail.present?

    self.class.reason_label_for(:loss, loss_reason, company: company)
  end

  def display_stalled_reason
    return if stalled_reason.blank?
    return stalled_reason_detail if stalled_reason == "other" && stalled_reason_detail.present?

    stalled_reason.humanize
  end

  def latest_revision_for_quote_no?
    relation = self.class.where(company_id: company_id, quote_no: quote_no)
    relation = relation.where(archived_at: nil) if self.class.column_names.include?("archived_at")
    relation = relation.where(deleted_at: nil) if self.class.column_names.include?("deleted_at")
    relation.maximum(:revision_number).to_i == revision_number.to_i
  end

  def workflow_state
    normalized = status.to_s.downcase
    return "accepted" if accepted_at.present? || normalized == "won"
    return "lost" if normalized == "lost"
    return "expired" if normalized == "expired"
    return "negotiating" if normalized == "negotiating" || changes_requested_at.present?
    return "draft" if normalized.blank? || normalized == "draft" || normalized == "pending"
    return "sent" if normalized == "sent"
    return "viewed" if normalized == "viewed"

    normalized
  end

  def can_edit_revision?
    return false if archived?
    return false unless latest_revision_for_quote_no?

    draft? || %w[revision_requested negotiating].include?(status.to_s) || pi_document?
  end

  def can_create_new_revision?
    !archived? && %w[sent viewed negotiating lost].include?(workflow_state) && latest_revision_for_quote_no?
  end

  def can_reopen?
    return false if archived?
    return false unless latest_revision_for_quote_no?

    %w[sent viewed negotiating accepted lost].include?(workflow_state)
  end

  def can_delete_revision?
    false
  end

  def archived?
    self.class.column_names.include?("archived_at") && archived_at.present?
  end

  def deleted?
    self.class.column_names.include?("deleted_at") && deleted_at.present?
  end

  def can_archive_revision?
    return false unless self.class.column_names.include?("archived_at")
    return false if archived?
    return false if deleted?

    !latest_revision_for_quote_no?
  end

  def seller_signature_image_constraints
    validate_formal_closing_image_constraints(:seller_signature_image)
  end

  def seller_stamp_image_constraints
    validate_formal_closing_image_constraints(:seller_stamp_image)
  end

  def can_delete_quote_family?
    return false if deleted?
    return false if archived?

    latest_revision_for_quote_no?
  end

  def can_share_publicly?
    return false if archived?

    %w[draft sent viewed negotiating].include?(workflow_state) &&
      latest_revision_for_quote_no? &&
      changes_requested_at.blank?
  end

  def pi_document?
    template&.document_kind.to_s == "proforma_invoice" || source_quote_id.present?
  end

  def can_generate_pi?
    return false if archived?
    return false unless latest_revision_for_quote_no?
    return false if pi_document?

    true
  end

  def can_send_reminder?
    return false if archived?
    return false unless latest_revision_for_quote_no?
    return false unless status.to_s == "sent"
    return false if viewed_at.present?
    return false if sent_at.blank?
    return false if reminder_sent_at.present? && reminder_sent_at > REMINDER_COOLDOWN.ago

    sent_at <= 48.hours.ago
  end

  def can_mark_sent?
    !archived? && workflow_state == "draft" && latest_revision_for_quote_no?
  end

  def can_mark_negotiating?
    !archived? && %w[sent viewed negotiating].include?(workflow_state) && latest_revision_for_quote_no?
  end

  def can_revert_to_sent?
    !archived? && workflow_state == "negotiating" && latest_revision_for_quote_no?
  end

  def can_mark_won?
    !archived? && %w[sent viewed negotiating expired].include?(workflow_state) && latest_revision_for_quote_no?
  end

  def can_mark_lost?
    !archived? && %w[sent viewed negotiating expired].include?(workflow_state) && latest_revision_for_quote_no?
  end

  def no_expiry_date?
    valid_until.blank?
  end

  def expired_by_date?
    valid_until.present? && valid_until < Date.current
  end

  def expires_in_days
    return nil if valid_until.blank?

    (valid_until - Date.current).to_i
  end

  def active_for_signal?
    %w[sent viewed negotiating].include?(status.to_s)
  end

  def engagement_score
    score = 0
    # View count: 2 points each
    score += view_count * 2
    # Revision requests: 5 points each
    score += revision_requests_count * 5
    # Average view duration: 1 point per minute
    avg_duration = avg_view_duration_seconds / 60
    score += avg_duration if avg_duration > 0
    score
  end

  def engagement_label
    case engagement_score
    when 0..5
      :cold
    when 6..15
      :warm
    else
      :hot
    end
  end

  def view_count
    quote_shares.sum(&:view_count).to_i
  end

  def last_viewed_at
    share_last_viewed_at =
      if association(:quote_shares).loaded?
        quote_shares.map(&:last_viewed_at).compact.max
      else
        quote_shares.maximum(:last_viewed_at)
      end

    [ viewed_at, share_last_viewed_at ].compact.max
  end

  def revision_requests_count
    changes_request_count = 0
    if changes_requested_at.present?
      # Count revisions created after this quote's first revision request
      earliest_change_request = Quote.where(quote_no: quote_no).where("changes_requested_at IS NOT NULL").minimum(:changes_requested_at)
      if earliest_change_request.present?
        change_request_revisions = Quote.where(quote_no: quote_no).where("created_at >= ?", earliest_change_request).count
        changes_request_count = change_request_revisions - 1  # Subtract 1 for the initial quote
      end
    end
    changes_request_count
  end

  def avg_view_duration_seconds
    quote_shares.map(&:avg_view_duration_seconds).sum / [ quote_shares.count, 1 ].max
  end

  def draft?
    workflow_state == "draft"
  end

  def resolved_spec_label
    spec_label.presence || template&.spec_label.presence || "Spec"
  end

  def resolved_addon_label
    addon_label.presence || template&.addon_label.presence || "Add-on"
  end

  def subtotal
    quote_items
      .reject(&:marked_for_destruction?)
      .sum(&:line_total)
      .round(2)
  end

  def grand_total
    (subtotal + tax_amount.to_d + shipping_amount.to_d - discount_amount.to_d).round(2)
  end

  def advanced_trade_terms_data
    normalized_advanced_hash(advanced_trade_terms, allowed_keys: ADVANCED_TRADE_TERMS_KEYS)
  end

  def advanced_trade_terms_state
    normalized_advanced_hash(advanced_trade_terms, allowed_keys: ADVANCED_TRADE_TERMS_KEYS, keep_blank: true)
  end

  def advanced_logistics_data
    normalized_advanced_hash(advanced_logistics, allowed_keys: ADVANCED_LOGISTICS_KEYS)
  end

  def advanced_logistics_state
    normalized_advanced_hash(advanced_logistics, allowed_keys: ADVANCED_LOGISTICS_KEYS, keep_blank: true)
  end

  def advanced_sections_have_values?
    advanced_trade_terms_data.any? || advanced_logistics_data.any?
  end

  def configuration_block_state(product_block: nil, fallback_block: nil)
    resolve_quote_level_block(
      quote_block: normalized_configuration_block(configuration_block, keep_blank: true),
      lower_priority_blocks: [
        normalized_configuration_block(product_block, keep_blank: true),
        normalized_configuration_block(fallback_block, keep_blank: true)
      ]
    )
  end

  def configuration_block_data(product_block: nil, fallback_block: nil)
    state = configuration_block_state(product_block: product_block, fallback_block: fallback_block)
    enabled = ActiveModel::Type::Boolean.new.cast(state["enabled"])
    rows = normalize_configuration_rows(state["rows"])
    notes = state["notes"].to_s.squish

    result = {
      "enabled" => enabled,
      "rows" => rows
    }
    result["notes"] = notes if notes.present?
    result
  end

  def detail_pictures_block_state(product_block: nil, fallback_block: nil)
    resolve_quote_level_block(
      quote_block: normalized_detail_pictures_block(detail_pictures_block, keep_blank: true),
      lower_priority_blocks: [
        normalized_detail_pictures_block(product_block, keep_blank: true),
        normalized_detail_pictures_block(fallback_block, keep_blank: true)
      ]
    )
  end

  def detail_pictures_block_data(product_block: nil, fallback_block: nil)
    state = detail_pictures_block_state(product_block: product_block, fallback_block: fallback_block)
    enabled = ActiveModel::Type::Boolean.new.cast(state["enabled"])
    items = normalize_detail_picture_items(state["items"])

    {
      "enabled" => enabled,
      "items" => items
    }
  end

  def container_loading_block_state(product_block: nil, fallback_block: nil)
    unless self.class.column_names.include?("container_loading_block")
      return {
        "enabled" => false,
        "headers" => DEFAULT_CONTAINER_LOADING_HEADERS.dup,
        "note_enabled" => true,
        "rows" => []
      }
    end

    resolve_quote_level_block(
      quote_block: normalized_container_loading_block(container_loading_block, keep_blank: true),
      lower_priority_blocks: [
        normalized_container_loading_block(product_block, keep_blank: true),
        normalized_container_loading_block(fallback_block, keep_blank: true)
      ]
    )
  end

  def container_loading_block_data(product_block: nil, fallback_block: nil)
    unless self.class.column_names.include?("container_loading_block")
      return {
        "enabled" => false,
        "headers" => DEFAULT_CONTAINER_LOADING_HEADERS.dup,
        "note_enabled" => true,
        "rows" => []
      }
    end

    state = container_loading_block_state(product_block: product_block, fallback_block: fallback_block)
    enabled = ActiveModel::Type::Boolean.new.cast(state["enabled"])
    headers = normalized_container_loading_headers(state["headers"])
    note_enabled = if state.key?("note_enabled")
      ActiveModel::Type::Boolean.new.cast(state["note_enabled"])
    else
      true
    end
    rows = normalize_container_loading_rows(state["rows"])

    {
      "enabled" => enabled,
      "headers" => headers,
      "note_enabled" => note_enabled,
      "rows" => rows
    }
  end

  def formal_closing_block_state
    unless self.class.column_names.include?("formal_closing_block")
      return {}
    end

    normalized_formal_closing_block(formal_closing_block, keep_blank: true)
  end

  def formal_closing_block_data
    unless self.class.column_names.include?("formal_closing_block")
      return {}
    end

    state = formal_closing_block_state
    result = {}
    if state.key?("buyer_signature_line_enabled")
      result["buyer_signature_line_enabled"] = ActiveModel::Type::Boolean.new.cast(state["buyer_signature_line_enabled"])
    end
    %w[
      pi_number
      payment_term
      trade_term
      delivery_time
      bank_route
      beneficiary_details
      remittance_note
    ].each do |key|
      value = state[key].to_s.squish
      result[key] = value if value.present?
    end
    result
  end

  def document_number_for(kind)
    normalized_kind = template&.normalize_document_kind(kind) || "quote"
    return quote_no unless normalized_kind == "pi"

    formal_pi_number = formal_closing_block_data["pi_number"].to_s.squish
    formal_pi_number.presence || quote_no
  end

  def advanced_visibility_data(template: self.template)
    quote_flags = normalized_boolean_hash(advanced_visibility, allowed_keys: ADVANCED_VISIBILITY_KEYS)
    trade_terms_present = advanced_trade_terms_data.any?
    logistics_present = advanced_logistics_data.any?

    ADVANCED_VISIBILITY_KEYS.index_with do |key|
      next true if quote_flags[key] == true

      case key
      when "show_trade_terms_advanced" then trade_terms_present
      when "show_logistics_block" then logistics_present
      else false
      end
    end
  end

  def advanced_section_enabled?(key, template: self.template)
    return false unless advanced_mode

    advanced_visibility_data(template: template)[key.to_s] || false
  end

  def build_revision
    revision_attrs = {
      company_id: company_id,
      customer_id: customer_id,
      template_id: template_id,
      quote_no: quote_no,
      currency: currency,
      valid_until: revision_valid_until,
      issued_on: issued_on,
      payment_term: payment_term,
      status: status_for_new_revision,
      negotiated: negotiated,
      final_amount: final_amount,
      win_reason: nil,
      win_reason_detail: nil,
      loss_reason: nil,
      loss_reason_detail: nil,
      stalled_reason: nil,
      stalled_reason_detail: nil,
      custom_title: custom_title,
      spec_label: spec_label,
      addon_label: addon_label,
      notes: notes,
      tax_amount: tax_amount,
      shipping_amount: shipping_amount,
      discount_amount: discount_amount,
      terms_text: terms_text,
      legal_disclaimer: legal_disclaimer,
      delivery_notes: delivery_notes,
      scope_of_supply: scope_of_supply,
      accepted_at: nil,
      won_at: nil,
      lost_at: nil,
      changes_requested_at: nil,
      changes_request_message: nil,
      request_reason: request_reason,
      reopened_at: nil
    }
    revision_attrs[:trade_term] = trade_term if self.class.column_names.include?("trade_term")
    revision_attrs[:advanced_mode] = advanced_mode if self.class.column_names.include?("advanced_mode")
    revision_attrs[:advanced_trade_terms] = advanced_trade_terms_state if self.class.column_names.include?("advanced_trade_terms")
    revision_attrs[:advanced_logistics] = advanced_logistics_state if self.class.column_names.include?("advanced_logistics")
    revision_attrs[:advanced_visibility] = normalized_boolean_hash(advanced_visibility, allowed_keys: ADVANCED_VISIBILITY_KEYS) if self.class.column_names.include?("advanced_visibility")
    revision_attrs[:configuration_block] = configuration_block_state if self.class.column_names.include?("configuration_block")
    revision_attrs[:detail_pictures_block] = detail_pictures_block_state if self.class.column_names.include?("detail_pictures_block")
    revision_attrs[:container_loading_block] = container_loading_block_state if self.class.column_names.include?("container_loading_block")
    revision_attrs[:formal_closing_block] = formal_closing_block_state if self.class.column_names.include?("formal_closing_block")
    revision = self.class.new(revision_attrs)

    item_columns = QuoteItem.column_names
    quote_items.ordered.each do |item|
      item_attrs = {
        product_id: item.product_id,
        description: item.description,
        unit_price: item.unit_price,
        quantity: item.quantity
      }
      item_attrs[:specifications] = item.specification_pairs if item_columns.include?("specifications")
      item_attrs[:addon_charges] = item.addon_charge_entries if item_columns.include?("addon_charges")
      item_attrs[:spec_snapshot] = item.specification_pairs if item_columns.include?("spec_snapshot")
      item_attrs[:addon_snapshot] = item.addon_charge_entries if item_columns.include?("addon_snapshot")
      item_attrs[:image_source] = item.image_source if item_columns.include?("image_source")
      revision.quote_items.build(item_attrs)
    end

    quote_items.ordered.each_with_index do |item, index|
      next unless item.item_image.attached?

      revision.quote_items[index]&.item_image&.attach(item.item_image.blob)
    end

    revision
  end

  private

  def status_for_new_revision
    "draft"
  end

  def revision_valid_until
    return nil if valid_until.present? && valid_until < Date.current

    valid_until
  end

  def set_revision_number
    last_revision = Quote
      .where(company_id: company_id, quote_no: quote_no)
      .maximum(:revision_number)

    self.revision_number = last_revision.to_i + 1
  end

  def generate_quote_no
    self.quote_no ||= "QT-#{SecureRandom.hex(6).upcase}"
  end

  def must_have_at_least_one_quote_item
    return if quote_items.reject(&:marked_for_destruction?).any?

    errors.add(:quote_items, "must include at least one item")
  end

  def quote_item_count_within_limit
    count = quote_items.reject(&:marked_for_destruction?).size
    return if count <= MAX_QUOTE_ITEMS_COUNT

    errors.add(:quote_items, "can include up to #{MAX_QUOTE_ITEMS_COUNT} items")
  end

  def discount_not_greater_than_subtotal
    return if discount_amount.blank?
    return unless discount_amount.to_d > subtotal.to_d

    errors.add(:discount_amount, "cannot be greater than subtotal")
  end

  def set_defaults
    self.currency = "USD" if currency.blank?
    self.buyer_locale = company&.quote_language.presence_in(BUYER_LOCALES) || "en" if buyer_locale.blank?
    self.status = "draft" if status.blank?
    self.issued_on ||= Date.current
    self.tax_amount ||= 0
    self.shipping_amount ||= 0
    self.discount_amount ||= 0
    self.template ||= company&.quote_template_or_default
    self.spec_label = template&.spec_label.presence || "Spec" if spec_label.blank?
    self.addon_label = template&.addon_label.presence || "Add-on" if addon_label.blank?
    self.advanced_mode = false if advanced_mode.nil?
    self.advanced_trade_terms = {} if advanced_trade_terms.blank?
    self.advanced_logistics = {} if advanced_logistics.blank?
    self.advanced_visibility = {} if advanced_visibility.blank?
    self.configuration_block = {} if configuration_block.blank? && self.class.column_names.include?("configuration_block")
    self.detail_pictures_block = {} if detail_pictures_block.blank? && self.class.column_names.include?("detail_pictures_block")
    self.container_loading_block = {} if container_loading_block.blank? && self.class.column_names.include?("container_loading_block")
    self.formal_closing_block = {} if formal_closing_block.blank? && self.class.column_names.include?("formal_closing_block")
  end

  def normalize_status
    self.status = normalize_status_value(status)
  end

  def apply_auto_expired_status
    normalized_status = normalize_status_value(status)
    return unless OPEN_STATUSES.include?(normalized_status)
    return unless valid_until.present? && valid_until < Date.current

    self.status = "expired"
  end

  def normalize_status_value(raw_status)
    normalized = raw_status.to_s.downcase
    return "draft" if normalized == "pending"

    normalized.presence
  end

  def set_final_amount_from_grand_total_for_won
    return unless normalize_status_value(status) == "won"
    return if final_amount.present?

    self.final_amount = grand_total
  end

  def sync_status_transition_timestamps
    return unless will_save_change_to_status?

    normalized_status = normalize_status_value(status)

    if normalized_status == "won" && self.class.column_names.include?("won_at")
      self.won_at = Time.current
    end

    if normalized_status == "lost" && self.class.column_names.include?("lost_at")
      self.lost_at = Time.current
    end
  end

  def final_amount_required_for_won
    return unless normalize_status_value(status) == "won"
    return if final_amount.present?

    errors.add(:final_amount, "is required when quote status is Won")
  end

  def loss_reason_required_for_lost
    return unless normalize_status_value(status) == "lost"
    return if loss_reason.present?

    errors.add(:loss_reason, "is required when quote status is Lost")
  end

  def win_reason_required_for_won
    return unless normalize_status_value(status) == "won"
    return if win_reason.present?

    errors.add(:win_reason, "is required when quote status is Won")
  end

  def custom_reason_details_required_for_other
    if normalize_status_value(status) == "won" && win_reason == "other" && win_reason_detail.blank?
      errors.add(:win_reason_detail, "is required when Win reason is Other")
    end

    if normalize_status_value(status) == "lost" && loss_reason == "other" && loss_reason_detail.blank?
      errors.add(:loss_reason_detail, "is required when Loss reason is Other")
    end

    if OPEN_STATUSES.include?(normalize_status_value(status)) && stalled_reason == "other" && stalled_reason_detail.blank?
      errors.add(:stalled_reason_detail, "is required when Stalled reason is Other")
    end
  end

  def monetary_values_fit_storage_precision
    {
      tax_amount: tax_amount,
      shipping_amount: shipping_amount,
      discount_amount: discount_amount,
      final_amount: final_amount
    }.each do |field, value|
      next if value.blank?
      next if value.to_d <= MAX_DECIMAL_15_4

      errors.add(field, "is too large")
    end
  end

  def grand_total_fits_storage_precision
    return if grand_total <= MAX_DECIMAL_15_4

    errors.add(:base, "Grand total is too large. Reduce unit prices, quantities, or add-ons.")
  end

  def valid_until_cannot_be_in_the_past
    return unless new_record? || will_save_change_to_valid_until?
    return if valid_until.blank?
    return unless valid_until < Date.current

    errors.add(:valid_until, I18n.t("quotes.errors.valid_until_on_or_after_today"))
  end

  def total_text_budget_within_limit
    total_chars = 0
    total_chars += notes.to_s.length
    total_chars += terms_text.to_s.length
    total_chars += legal_disclaimer.to_s.length
    total_chars += delivery_notes.to_s.length
    total_chars += scope_of_supply.to_s.length
    total_chars += changes_request_message.to_s.length
    total_chars += advanced_trade_terms_data.values.join.length
    total_chars += advanced_logistics_data.values.join.length
    total_chars += configuration_block_data["rows"].sum { |row| row["label"].to_s.length + row["value"].to_s.length }
    total_chars += configuration_block_data["notes"].to_s.length
    total_chars += detail_pictures_block_data["items"].sum { |item| item["caption"].to_s.length }
    total_chars += container_loading_block_data["rows"].sum do |row|
      row["variant"].to_s.length + row["container_type"].to_s.length + row["capacity"].to_s.length + row["note"].to_s.length
    end
    total_chars += container_loading_block_data["headers"].values.join.length
    total_chars += formal_closing_block_data.values.join.length if self.class.column_names.include?("formal_closing_block")

    quote_items.reject(&:marked_for_destruction?).each do |item|
      total_chars += item.description.to_s.length
      item.specification_pairs.each do |pair|
        total_chars += pair[:key].to_s.length
        total_chars += pair[:value].to_s.length
      end
      item.addon_charge_entries.each do |entry|
        total_chars += entry[:name].to_s.length
      end
    end

    return if total_chars <= MAX_TOTAL_TEXT_BUDGET

    errors.add(:base, "Total quotation text is too large (maximum is #{MAX_TOTAL_TEXT_BUDGET} characters across quote fields and line items).")
  end

  def normalize_advanced_blocks
    self.advanced_trade_terms = normalized_advanced_hash(advanced_trade_terms, allowed_keys: ADVANCED_TRADE_TERMS_KEYS, keep_blank: true)
    self.advanced_logistics = normalized_advanced_hash(advanced_logistics, allowed_keys: ADVANCED_LOGISTICS_KEYS, keep_blank: true)
    self.advanced_visibility = normalized_boolean_hash(advanced_visibility, allowed_keys: ADVANCED_VISIBILITY_KEYS)
    self.configuration_block = normalized_configuration_block(configuration_block, keep_blank: true) if self.class.column_names.include?("configuration_block")
    self.detail_pictures_block = normalized_detail_pictures_block(detail_pictures_block, keep_blank: true) if self.class.column_names.include?("detail_pictures_block")
    self.container_loading_block = normalized_container_loading_block(container_loading_block, keep_blank: true) if self.class.column_names.include?("container_loading_block")
    self.formal_closing_block = normalized_formal_closing_block(formal_closing_block, keep_blank: true) if self.class.column_names.include?("formal_closing_block")
  end

  def normalized_configuration_block(raw, keep_blank: false)
    source = normalize_hash_source(raw)
    result = {}

    if source.key?("rows") || source.key?(:rows)
      rows = normalize_configuration_rows(source["rows"] || source[:rows])
      result["rows"] = rows if rows.any? || keep_blank
    elsif keep_blank
      result["rows"] = []
    end

    if source.key?("notes") || source.key?(:notes)
      notes = (source["notes"] || source[:notes]).to_s.squish
      result["notes"] = keep_blank ? notes : notes.presence
    elsif keep_blank
      result["notes"] = ""
    end
    result.compact
  end

  def normalized_detail_pictures_block(raw, keep_blank: false)
    source = normalize_hash_source(raw)
    result = {}
    if source.key?("enabled") || source.key?(:enabled)
      result["enabled"] = ActiveModel::Type::Boolean.new.cast(source["enabled"] || source[:enabled])
    elsif keep_blank
      result["enabled"] = false
    end

    if source.key?("items") || source.key?(:items)
      items = normalize_detail_picture_items(source["items"] || source[:items])
      result["items"] = items if items.any? || keep_blank
    elsif keep_blank
      result["items"] = []
    end
    result
  end

  def normalized_container_loading_block(raw, keep_blank: false)
    source = normalize_hash_source(raw)
    result = {}
    if source.key?("enabled") || source.key?(:enabled)
      result["enabled"] = ActiveModel::Type::Boolean.new.cast(source["enabled"] || source[:enabled])
    elsif keep_blank
      result["enabled"] = false
    end

    if source.key?("headers") || source.key?(:headers)
      result["headers"] = normalized_container_loading_headers(source["headers"] || source[:headers])
    elsif keep_blank
      result["headers"] = DEFAULT_CONTAINER_LOADING_HEADERS.dup
    end

    if source.key?("note_enabled") || source.key?(:note_enabled)
      result["note_enabled"] = ActiveModel::Type::Boolean.new.cast(source["note_enabled"] || source[:note_enabled])
    elsif keep_blank
      result["note_enabled"] = true
    end

    if source.key?("rows") || source.key?(:rows)
      rows = normalize_container_loading_rows(source["rows"] || source[:rows])
      result["rows"] = rows if rows.any? || keep_blank
    elsif keep_blank
      result["rows"] = []
    end
    result
  end

  def normalized_formal_closing_block(raw, keep_blank: false)
    source = normalize_hash_source(raw)
    result = {}

    if source.key?("buyer_signature_line_enabled") || source.key?(:buyer_signature_line_enabled)
      result["buyer_signature_line_enabled"] = ActiveModel::Type::Boolean.new.cast(source["buyer_signature_line_enabled"] || source[:buyer_signature_line_enabled])
    elsif keep_blank
      result["buyer_signature_line_enabled"] = false
    end

    %w[
      pi_number
      payment_term
      trade_term
      delivery_time
      bank_route
      beneficiary_details
      remittance_note
    ].each do |key|
      if source.key?(key) || source.key?(key.to_sym)
        cleaned = (source[key] || source[key.to_sym]).to_s.squish
        result[key] = keep_blank ? cleaned : cleaned.presence
      elsif keep_blank
        result[key] = ""
      end
    end

    result.compact
  end

  def normalize_configuration_rows(raw_rows)
    rows =
      if raw_rows.is_a?(Array)
        raw_rows
      elsif raw_rows.is_a?(Hash)
        raw_rows.values
      else
        []
      end
    rows.filter_map do |row|
      source = normalize_hash_source(row)
      label = (source["label"] || source[:label] || source["key"] || source[:key]).to_s.squish
      value = (source["value"] || source[:value]).to_s.squish
      next if label.blank? || value.blank?

      source_name = (source["source"] || source[:source]).to_s.squish
      source_name = "quote" unless CONFIGURATION_BLOCK_ROW_SOURCES.include?(source_name)
      {
        "label" => label,
        "value" => value,
        "source" => source_name,
        "position" => (source["position"] || source[:position]).to_i
      }
    end.sort_by { |row| [ row["position"], row["label"] ] }
  end

  def normalize_detail_picture_items(raw_items)
    items =
      if raw_items.is_a?(Array)
        raw_items
      elsif raw_items.is_a?(Hash)
        raw_items.values
      else
        []
      end
    items.filter_map do |item|
      source = normalize_hash_source(item)
      image_blob_id = (source["image_blob_id"] || source[:image_blob_id]).to_s.squish
      next if image_blob_id.blank?

      source_name = (source["source"] || source[:source]).to_s.squish
      source_name = "quote_upload" unless DETAIL_PICTURES_ITEM_SOURCES.include?(source_name)
      {
        "image_blob_id" => image_blob_id,
        "caption" => (source["caption"] || source[:caption]).to_s.squish,
        "source" => source_name,
        "position" => (source["position"] || source[:position]).to_i
      }
    end.sort_by { |item| [ item["position"], item["image_blob_id"] ] }
  end

  def normalize_container_loading_rows(raw_rows)
    rows =
      if raw_rows.is_a?(Array)
        raw_rows
      elsif raw_rows.is_a?(Hash)
        raw_rows.values
      else
        []
      end

    rows.filter_map do |row|
      source = normalize_hash_source(row)
      variant = (source["variant"] || source[:variant]).to_s.squish
      container_type = (source["container_type"] || source[:container_type]).to_s.squish
      capacity = (source["capacity"] || source[:capacity]).to_s.squish
      note = (source["note"] || source[:note]).to_s.squish
      next if variant.blank? && container_type.blank? && capacity.blank? && note.blank?

      {
        "variant" => variant,
        "container_type" => container_type,
        "capacity" => capacity,
        "note" => note,
        "position" => (source["position"] || source[:position]).to_i
      }
    end.sort_by { |row| [ row["position"], row["variant"], row["container_type"] ] }
  end

  def resolve_quote_level_block(quote_block:, lower_priority_blocks:)
    resolved = {}
    [ quote_block, *lower_priority_blocks.compact ].each do |block|
      block_hash = normalize_hash_source(block)
      next if block_hash.empty?

      block_hash.each do |key, value|
        next if resolved.key?(key.to_s)

        resolved[key.to_s] = value
      end
    end
    resolved
  end

  def normalized_container_loading_headers(raw_headers)
    source = normalize_hash_source(raw_headers)
    DEFAULT_CONTAINER_LOADING_HEADERS.each_with_object({}) do |(key, fallback), acc|
      raw_value = source[key] || source[key.to_sym]
      cleaned = raw_value.to_s.squish
      cleaned = fallback if cleaned.blank?
      acc[key] = cleaned.first(MAX_CONTAINER_LOADING_HEADER_LENGTH)
    end
  end

  def normalize_hash_source(raw)
    if raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h
    elsif raw.is_a?(Hash)
      raw
    else
      {}
    end
  end

  def configuration_block_within_limit
    rows = configuration_block_data["rows"]
    return if rows.size <= MAX_CONFIGURATION_BLOCK_ROWS

    errors.add(:configuration_block, "rows exceed limit (#{MAX_CONFIGURATION_BLOCK_ROWS})")
  end

  def detail_pictures_block_within_limit
    items = detail_pictures_block_data["items"]
    return if items.size <= MAX_DETAIL_PICTURES_ITEMS

    errors.add(:detail_pictures_block, "items exceed limit (#{MAX_DETAIL_PICTURES_ITEMS})")
  end

  def configuration_block_value_lengths
    rows = configuration_block_data["rows"]
    rows.each do |row|
      if row["label"].to_s.length > MAX_CONFIGURATION_LABEL_LENGTH
        errors.add(:configuration_block, "label is too long (maximum is #{MAX_CONFIGURATION_LABEL_LENGTH} characters)")
        break
      end
      if row["value"].to_s.length > MAX_CONFIGURATION_VALUE_LENGTH
        errors.add(:configuration_block, "value is too long (maximum is #{MAX_CONFIGURATION_VALUE_LENGTH} characters)")
        break
      end
    end

    notes = configuration_block_data["notes"].to_s
    if notes.length > MAX_CONFIGURATION_NOTES_LENGTH
      errors.add(:configuration_block, "notes are too long (maximum is #{MAX_CONFIGURATION_NOTES_LENGTH} characters)")
    end
  end

  def detail_pictures_block_item_constraints
    items = detail_pictures_block_data["items"]
    return if items.blank?

    duplicates = items.group_by { |item| item["image_blob_id"].to_s }.select { |_blob_id, rows| rows.size > 1 }.keys
    if duplicates.any?
      errors.add(:detail_pictures_block, "contains duplicate images")
      return
    end

    blobs = ActiveStorage::Blob.where(id: items.map { |item| item["image_blob_id"] }).index_by { |blob| blob.id.to_s }
    missing = items.map { |item| item["image_blob_id"].to_s }.reject { |id| blobs.key?(id) }
    if missing.any?
      errors.add(:detail_pictures_block, "contains missing images")
      return
    end

    items.each do |item|
      caption = item["caption"].to_s
      if caption.length > MAX_DETAIL_PICTURE_CAPTION_LENGTH
        errors.add(:detail_pictures_block, "caption is too long (maximum is #{MAX_DETAIL_PICTURE_CAPTION_LENGTH} characters)")
        break
      end

      blob = blobs[item["image_blob_id"].to_s]
      next if blob.blank?

      unless blob.content_type.to_s.start_with?("image/")
        errors.add(:detail_pictures_block, "must reference image files only")
        break
      end
      if blob.byte_size.to_i > QuoteItem::MAX_IMAGE_SIZE
        max_mb = QuoteItem::MAX_IMAGE_SIZE / 1.megabyte
        errors.add(:detail_pictures_block, "image must be smaller than #{max_mb}MB")
        break
      end
    end
  end

  def container_loading_block_within_limit
    return unless self.class.column_names.include?("container_loading_block")

    rows = container_loading_block_data["rows"]
    return if rows.size <= MAX_CONTAINER_LOADING_ROWS

    errors.add(:container_loading_block, "rows exceed limit (#{MAX_CONTAINER_LOADING_ROWS})")
  end

  def container_loading_block_value_lengths
    return unless self.class.column_names.include?("container_loading_block")

    headers = container_loading_block_data["headers"]
    headers.each_value do |value|
      if value.to_s.length > MAX_CONTAINER_LOADING_HEADER_LENGTH
        errors.add(:container_loading_block, "header is too long (maximum is #{MAX_CONTAINER_LOADING_HEADER_LENGTH} characters)")
        break
      end
    end

    rows = container_loading_block_data["rows"]
    rows.each do |row|
      if row["variant"].to_s.length > MAX_CONTAINER_LOADING_CELL_LENGTH
        errors.add(:container_loading_block, "variant is too long (maximum is #{MAX_CONTAINER_LOADING_CELL_LENGTH} characters)")
        break
      end
      if row["container_type"].to_s.length > MAX_CONTAINER_LOADING_CELL_LENGTH
        errors.add(:container_loading_block, "container_type is too long (maximum is #{MAX_CONTAINER_LOADING_CELL_LENGTH} characters)")
        break
      end
      if row["capacity"].to_s.length > MAX_CONTAINER_LOADING_CELL_LENGTH
        errors.add(:container_loading_block, "capacity is too long (maximum is #{MAX_CONTAINER_LOADING_CELL_LENGTH} characters)")
        break
      end
      if row["note"].to_s.length > MAX_CONTAINER_LOADING_CELL_LENGTH
        errors.add(:container_loading_block, "note is too long (maximum is #{MAX_CONTAINER_LOADING_CELL_LENGTH} characters)")
        break
      end
    end
  end

  def formal_closing_block_value_lengths
    return unless self.class.column_names.include?("formal_closing_block")

    payload = formal_closing_block_data
    %w[
      pi_number
      payment_term
      trade_term
      delivery_time
      bank_route
      beneficiary_details
      remittance_note
    ].each do |key|
      next unless payload[key].to_s.length > MAX_FORMAL_CLOSING_FIELD_LENGTH

      errors.add(:formal_closing_block, "#{key} is too long (maximum is #{MAX_FORMAL_CLOSING_FIELD_LENGTH} characters)")
      break
    end
  end

  def validate_formal_closing_image_constraints(name)
    attachment = public_send(name)
    return unless attachment.attached?

    if !FORMAL_CLOSING_IMAGE_CONTENT_TYPES.include?(attachment.blob.content_type)
      errors.add(name, "must be an image (PNG, JPG, WEBP, GIF, or SVG)")
    end
    if attachment.blob.byte_size > MAX_FORMAL_CLOSING_IMAGE_SIZE
      errors.add(name, "must be smaller than #{MAX_FORMAL_CLOSING_IMAGE_SIZE / 1.megabyte}MB")
    end
  end

  def normalized_advanced_hash(raw, allowed_keys:, keep_blank: false)
    source = if raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h
    elsif raw.is_a?(Hash)
      raw
    else
      {}
    end

    allowed_keys.each_with_object({}) do |key, acc|
      has_value = source.key?(key) || source.key?(key.to_sym)
      next unless has_value

      value = source[key] || source[key.to_sym]
      cleaned = value.to_s.squish
      if keep_blank
        acc[key] = cleaned
      elsif cleaned.present?
        acc[key] = cleaned
      end
    end
  end

  def normalized_boolean_hash(raw, allowed_keys:)
    source = if raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h
    elsif raw.is_a?(Hash)
      raw
    else
      {}
    end
    caster = ActiveModel::Type::Boolean.new

    allowed_keys.each_with_object({}) do |key, acc|
      next unless source.key?(key) || source.key?(key.to_sym)

      acc[key] = caster.cast(source[key] || source[key.to_sym])
    end
  end

  def reason_values_are_allowed
    if will_save_change_to_win_reason? && win_reason.present? && !self.class.reason_options_for(:win, company: company).include?(win_reason)
      errors.add(:win_reason, "is not supported")
    end

    if will_save_change_to_loss_reason? && loss_reason.present? && !self.class.reason_options_for(:loss, company: company).include?(loss_reason)
      errors.add(:loss_reason, "is not supported")
    end

    if will_save_change_to_stalled_reason? && stalled_reason.present? && !STALLED_REASONS.include?(stalled_reason)
      errors.add(:stalled_reason, "is not supported")
    end
  end

  class << self
    def expire_overdue_for_company!(company_id)
      where(company_id: company_id)
        .where(status: OPEN_STATUSES)
        .where.not(valid_until: nil)
        .where("valid_until < ?", Date.current)
        .update_all(status: "expired", updated_at: Time.current)
    end

    def reason_options_for(kind, company: nil)
      normalized_kind = kind.to_sym

      reason_option_pairs_for(normalized_kind, company: company).map { |(_label, key)| key }
    end

    def reason_option_pairs_for(kind, company: nil)
      normalized_kind = kind.to_sym

      pairs = default_reason_option_pairs_for(normalized_kind)

      if company.present? && normalized_kind.in?([ :win, :loss ]) && defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?
        configured_reason_option_pairs_for(company, normalized_kind).each do |label, key|
          index = pairs.index { |(_existing_label, existing_key)| existing_key == key }
          if index
            pairs[index] = [ label, key ]
          else
            pairs << [ label, key ]
          end
        end
      end

      pairs
    end

    def reason_label_for(kind, value, company: nil)
      return if value.blank?

      normalized_kind = kind.to_sym
      key = value.to_s
      if company.present? && normalized_kind.in?([ :win, :loss ]) && defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?
        label = company.quote_reason_options.active.for_kind(normalized_kind).where(key: key).pick(:label)
        return label if label.present?
      end

      case normalized_kind
      when :win
        I18n.t("analytics.reason_labels.win.#{key}", default: key.humanize)
      when :loss
        I18n.t("analytics.reason_labels.loss.#{key}", default: key.humanize)
      else
        key.humanize
      end
    end

    private

    def default_reason_option_pairs_for(kind)
      case kind.to_sym
      when :win
        WIN_REASONS
          .map { |reason| [ I18n.t("analytics.reason_labels.win.#{reason}", default: reason.humanize), reason ] }
      when :loss
        LOSS_REASONS
          .map { |reason| [ I18n.t("analytics.reason_labels.loss.#{reason}", default: reason.humanize), reason ] }
      when :stalled
        STALLED_REASONS.map { |reason| [ reason.humanize, reason ] }
      else
        []
      end
    end

    def configured_reason_option_pairs_for(company, kind)
      company.quote_reason_options.active.for_kind(kind).ordered.pluck(:label, :key)
    end
  end

  def self.currency_symbol_for(code)
    normalized = code.to_s.upcase
    CURRENCY_SYMBOLS.fetch(normalized, normalized.presence || "USD")
  end

  private

  def refresh_related_product_stats
    ProductIntelligenceRefresher.refresh_for_quote(self)
  end
end
