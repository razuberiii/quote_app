class Quote < ApplicationRecord
  belongs_to :company
  belongs_to :customer
  has_many :quote_items, dependent: :destroy
  accepts_nested_attributes_for :quote_items,
                                allow_destroy: true,
                                reject_if: lambda { |attrs|
                                  attrs["product_id"].blank? &&
                                    attrs["description"].blank? &&
                                    attrs["unit_price"].blank? &&
                                    attrs["quantity"].blank?
                                }

  before_create :generate_quote_no, :set_revision_number
  before_validation :set_defaults

  validates :currency, presence: true
  validates :status, inclusion: { in: %w[pending won lost] }, allow_nil: true
  validates :tax_amount, :shipping_amount, :discount_amount,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :must_have_at_least_one_quote_item
  validate :discount_not_greater_than_subtotal

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
      .sum { |item| item.amount.presence || (item.unit_price.to_d * item.quantity.to_i) }
      .round(2)
  end

  def grand_total
    (subtotal + tax_amount.to_d + shipping_amount.to_d - discount_amount.to_d).round(2)
  end

  def build_revision
    revision = self.class.new(
      company_id: company_id,
      customer_id: customer_id,
      quote_no: quote_no,
      currency: currency,
      valid_until: valid_until,
      issued_on: issued_on,
      payment_term: payment_term,
      status: status.presence || "pending",
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
    )

    quote_items.ordered.each do |item|
      revision.quote_items.build(
        product_id: item.product_id,
        description: item.description,
        unit_price: item.unit_price,
        quantity: item.quantity
      )
    end

    revision
  end

  private

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
    self.status = "pending" if status.blank?
    self.issued_on ||= Date.current
    self.tax_amount ||= 0
    self.shipping_amount ||= 0
    self.discount_amount ||= 0
  end
end
