class Product < ApplicationRecord
  belongs_to :company
  has_many :quote_items, dependent: :nullify
  has_one_attached :image

  before_validation :normalize_sku

  validates :name, presence: true
  validates :sku, presence: true
  validates :default_price, presence: true, numericality: { greater_than: 0 }
  validate :sku_must_be_unique_within_company

  scope :by_company, ->(company_id) { where(company_id: company_id) }

  private

  def normalize_sku
    self.sku = sku.to_s.strip.upcase.presence
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
