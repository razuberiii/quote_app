class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  FREE_CUSTOMER_LIMIT = 5
  FREE_QUOTE_LIMIT = 20

  enum :role, { user: 0, vip: 1, admin: 2 }, default: :user

  belongs_to :company
  before_validation :ensure_company, on: :create

  def can_create_customer?
    return true if vip? || admin?

    customer_count_for_limit < FREE_CUSTOMER_LIMIT
  end

  def can_create_quote?
    return true if vip? || admin?

    quote_count_for_limit < FREE_QUOTE_LIMIT
  end

  def customer_count_for_limit
    company.customers.count
  end

  def quote_count_for_limit
    company.quotes.where.not(quote_no: nil).distinct.count(:quote_no)
  end

  private

  def ensure_company
    self.company ||= Company.create!(name: "My Company")
  end
end
