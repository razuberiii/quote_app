class QuoteItem < ApplicationRecord
  belongs_to :quote
  belongs_to :product, optional: true

  validates :description, presence: true
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :product_company_matches_quote_company

  before_validation :apply_product_defaults
  before_validation :calculate_amount

  scope :ordered, -> { order(created_at: :asc) }

  private

  def apply_product_defaults
    return unless product

    self.description = product.name if description.blank?
    self.unit_price = product.default_price if unit_price.blank?
  end

  def calculate_amount
    return if unit_price.blank? || quantity.blank?

    self.amount = (unit_price * quantity).round(2)
  end

  def product_company_matches_quote_company
    return if product.blank? || quote.blank?
    return if product.company_id == quote.company_id

    errors.add(:product, "must belong to the same company as the quote")
  end
end
