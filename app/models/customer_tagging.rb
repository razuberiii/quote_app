class CustomerTagging < ApplicationRecord
  belongs_to :customer
  belongs_to :customer_tag

  validates :customer_tag_id, uniqueness: { scope: :customer_id }

  scope :ordered, -> { order(:position, :created_at) }
end
