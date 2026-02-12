class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  belongs_to :company
  before_validation :ensure_company, on: :create

  private

  def ensure_company
    self.company ||= Company.create!(name: "My Company")
  end
end
