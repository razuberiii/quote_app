class Quote < ApplicationRecord
  STATUSES = %w[draft sent viewed negotiating won lost expired pending].freeze
  OPEN_STATUSES = %w[draft sent viewed negotiating pending].freeze
  AUTO_VIEW_STATUSES = %w[draft sent pending].freeze

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

  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :tax_amount, :shipping_amount, :discount_amount,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :must_have_at_least_one_quote_item
  validate :discount_not_greater_than_subtotal
  validate :final_amount_required_for_won
  validate :loss_reason_required_for_lost

  scope :latest_versions, -> {
  select("DISTINCT ON (quote_no) *")
    .order(:quote_no, revision_number: :desc)
  }

  scope :search, ->(query) {
    return all if query.blank?

    query = "%#{query}%"
    where("quote_no ILIKE ? OR currency ILIKE ?", query, query)
  }

  def title
    quote_items.ordered.first&.description.presence || "Quotation #{quote_no}"
  end

  def display_amount
    negotiated? && final_amount.present? ? final_amount : grand_total
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
      loss_reason: loss_reason,
      notes: notes,
      tax_amount: tax_amount,
      shipping_amount: shipping_amount,
      discount_amount: discount_amount,
      terms_text: terms_text,
      legal_disclaimer: legal_disclaimer,
      delivery_notes: delivery_notes
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

  class << self
    def expire_overdue_for_company!(company_id)
      where(company_id: company_id)
        .where(status: OPEN_STATUSES)
        .where.not(valid_until: nil)
        .where("valid_until < ?", Date.current)
        .update_all(status: "expired", updated_at: Time.current)
    end
  end

  def self.currency_symbol_for(code)
    normalized = code.to_s.upcase
    CURRENCY_SYMBOLS.fetch(normalized, normalized.presence || "USD")
  end
end
