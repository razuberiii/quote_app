class SubscriptionEvent < ApplicationRecord
  belongs_to :company

  validates :provider_event_id, :event_type, presence: true
  validates :provider_event_id, uniqueness: true
end
