class Product < ApplicationRecord
  belongs_to :company
  has_many :quote_items, dependent: :nullify
  has_one_attached :image

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: { scope: :company_id }
  validates :default_price, presence: true, numericality: { greater_than: 0 }

  scope :by_company, ->(company_id) { where(company_id: company_id) }
end
