class Quote < ApplicationRecord
  REMINDER_COOLDOWN = 12.hours
  MAX_DECIMAL_15_4 = BigDecimal("99999999999.9999")
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
    "HKD" => "HK$"
  }.freeze

  belongs_to :company
  belongs_to :customer
  belongs_to :template, class_name: "QuoteTemplate", optional: true
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
  before_validation :set_defaults
  after_commit :refresh_related_product_stats, if: :saved_change_to_status?

  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :tax_amount, :shipping_amount, :discount_amount,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :must_have_at_least_one_quote_item
  validate :discount_not_greater_than_subtotal
  validate :final_amount_required_for_won
  validate :loss_reason_required_for_lost
  validate :win_reason_required_for_won
  validate :reason_values_are_allowed
  validate :monetary_values_fit_storage_precision
  validate :grand_total_fits_storage_precision

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

  def title
    custom_title.presence || quote_items.ordered.first&.description.presence || "Quotation #{quote_no}"
  end

  def display_amount
    negotiated? && final_amount.present? ? final_amount : grand_total
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
    !archived? && %w[sent viewed negotiating].include?(workflow_state) && latest_revision_for_quote_no?
  end

  def can_reopen?
    return false if archived?
    return false unless latest_revision_for_quote_no?

    %w[sent viewed negotiating].include?(workflow_state)
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

  def can_copy_and_reprice?
    !archived? && %w[sent viewed negotiating accepted lost expired].include?(workflow_state) && latest_revision_for_quote_no?
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

  def build_revision
    revision_attrs = {
      company_id: company_id,
      customer_id: customer_id,
      template_id: template_id,
      quote_no: quote_no,
      currency: currency,
      valid_until: valid_until,
      issued_on: issued_on,
      payment_term: payment_term,
      status: status_for_new_revision,
      negotiated: negotiated,
      final_amount: final_amount,
      win_reason: win_reason,
      loss_reason: loss_reason,
      stalled_reason: stalled_reason,
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
      accepted_at: nil,
      changes_requested_at: nil,
      changes_request_message: nil,
      request_reason: request_reason,
      reopened_at: nil
    }
    revision_attrs[:trade_term] = trade_term if self.class.column_names.include?("trade_term")
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
      revision.quote_items.build(item_attrs)
    end

    revision
  end

  private

  def status_for_new_revision
    normalized_status = normalize_status_value(status)
    return "draft" if %w[won lost expired].include?(normalized_status)

    normalized_status.presence || "draft"
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

  def reason_values_are_allowed
    if will_save_change_to_win_reason? && win_reason.present? && !WIN_REASONS.include?(win_reason)
      errors.add(:win_reason, "is not supported")
    end

    if will_save_change_to_loss_reason? && loss_reason.present? && !LOSS_REASONS.include?(loss_reason)
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

    def reason_options_for(kind)
      case kind.to_sym
      when :win
        WIN_REASONS
      when :loss
        LOSS_REASONS
      when :stalled
        STALLED_REASONS
      else
        []
      end
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
