class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :quotes, dependent: :destroy
  has_many :quote_shares, dependent: :destroy
  has_many :products, dependent: :destroy
  has_one :quote_template, dependent: :destroy
  has_one_attached :logo

  after_create :ensure_quote_template!

  def quote_template_or_default
    quote_template || build_quote_template
  end

  private

  def ensure_quote_template!
    create_quote_template! unless quote_template
  end
end
