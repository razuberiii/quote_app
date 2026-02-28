class Product < ApplicationRecord
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
  validate :sku_must_be_unique_within_company

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
end
