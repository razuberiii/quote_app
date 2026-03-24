class Quote < ApplicationRecord
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
  TEMPLATE_ADVANCED_TRADE_DEFAULT_KEYS = %w[
    trade_terms_hs_code
    trade_terms_warranty_scope_note
    trade_terms_support_scope_note
    trade_terms_validity_clause_note
    trade_terms_delivery_commitment_note
    trade_terms_payment_clause_note
  ].freeze
  TEMPLATE_ADVANCED_LOGISTICS_DEFAULT_KEYS = %w[
    logistics_freight_note
    logistics_container_type
    logistics_shipping_scope_note
    logistics_container_loading_note
  ].freeze
  TEMPLATE_ADVANCED_DEFAULT_FIELD_MAPPINGS = {
    "trade_terms_hs_code" => [ :trade_terms, "hs_code" ],
    "trade_terms_warranty_scope_note" => [ :trade_terms, "warranty_scope_note" ],
    "trade_terms_support_scope_note" => [ :trade_terms, "support_scope_note" ],
    "trade_terms_validity_clause_note" => [ :trade_terms, "validity_clause_note" ],
    "trade_terms_delivery_commitment_note" => [ :trade_terms, "delivery_commitment_note" ],
    "trade_terms_payment_clause_note" => [ :trade_terms, "payment_clause_note" ],
    "logistics_freight_note" => [ :logistics, "freight_note" ],
    "logistics_container_type" => [ :logistics, "container_type" ],
    "logistics_shipping_scope_note" => [ :logistics, "shipping_scope_note" ],
    "logistics_container_loading_note" => [ :logistics, "container_loading_note" ]
  }.freeze
  ADVANCED_VISIBILITY_KEYS = %w[
    show_trade_terms_advanced
    show_logistics_block
  ].freeze
  STATUSES = %w[draft sent viewed negotiating won lost expired pending].freeze
  OPEN_STATUSES = %w[draft sent viewed negotiating pending].freeze
  AUTO_VIEW_STATUSES = %w[draft sent pending].freeze
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
  belongs_to :customer
  belongs_to :template, class_name: "QuoteTemplate", optional: true
  has_many :customer_follow_up_events, dependent: :nullify
  has_many :quote_items, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
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
    !archived? && draft? && latest_revision_for_quote_no?
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

  def can_switch_document?
    !archived? && workflow_state == "accepted" && latest_revision_for_quote_no?
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

  def apply_template_advanced_defaults!(template: self.template)
    return if template.blank?
    return unless template.enable_advanced_by_default?

    self.advanced_mode = true if advanced_mode.nil? || advanced_mode == false
    trade_terms_state = advanced_trade_terms_state
    logistics_state = advanced_logistics_state
    visibility_state = normalized_boolean_hash(advanced_visibility, allowed_keys: ADVANCED_VISIBILITY_KEYS)

    template.advanced_defaults_data.each do |default_key, raw_value|
      value = raw_value.to_s.squish
      next if value.blank?

      mapped = TEMPLATE_ADVANCED_DEFAULT_FIELD_MAPPINGS[default_key.to_s]
      next if mapped.blank?

      target, target_key = mapped
      case target
      when :trade_terms
        trade_terms_state[target_key] = value unless trade_terms_state.key?(target_key)
      when :logistics
        logistics_state[target_key] = value unless logistics_state.key?(target_key)
      end
    end

    template.advanced_visibility_defaults_data.each do |key, value|
      next unless ADVANCED_VISIBILITY_KEYS.include?(key)
      next if visibility_state.key?(key)

      visibility_state[key] = ActiveModel::Type::Boolean.new.cast(value)
    end

    self.advanced_trade_terms = trade_terms_state
    self.advanced_logistics = logistics_state
    self.advanced_visibility = visibility_state
  end

  def advanced_visibility_data(template: self.template)
    quote_flags = normalized_boolean_hash(advanced_visibility, allowed_keys: ADVANCED_VISIBILITY_KEYS)
    template_flags = template&.advanced_visibility_defaults_data || {}
    trade_terms_present = advanced_trade_terms_data.any? || template_advanced_defaults_present?(template, TEMPLATE_ADVANCED_TRADE_DEFAULT_KEYS)
    logistics_present = advanced_logistics_data.any? || template_advanced_defaults_present?(template, TEMPLATE_ADVANCED_LOGISTICS_DEFAULT_KEYS)

    ADVANCED_VISIBILITY_KEYS.index_with do |key|
      next true if quote_flags[key] == true
      next true if template_flags[key] == true

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

  def template_advanced_defaults_present?(template, keys)
    defaults = template&.advanced_defaults_data
    return false unless defaults.is_a?(Hash)

    keys.any? { |key| defaults[key].to_s.strip.present? }
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
