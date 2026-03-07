class QuoteShare < ApplicationRecord
  belongs_to :company
  belongs_to :quote

  validates :token, presence: true, uniqueness: true
  validates :snapshot, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.generate_token
    SecureRandom.hex(12)
  end

  def track_view!(country: nil, ip: nil, user_agent: nil)
    now = Time.current
    first_view = false
    with_lock do
      first_view = first_viewed_at.blank?
      self.view_count = view_count.to_i + 1
      self.first_viewed_at ||= now
      self.last_viewed_at = now

      event = { "at" => now.utc.strftime("%Y-%m-%dT%H:%M:%SZ") }
      event["country"] = country if country.present?
      event["ip"] = ip if ip.present?
      event["ua"] = user_agent if user_agent.present?
      self.view_events = Array(view_events).last(199) + [ event ]
      save!(validate: false)
    end

    return unless quote.present?

    current_status = quote.status.to_s
    current_status = "draft" if current_status == "pending"
    next_status =
      if quote.status.to_s == "draft"
        quote.status
      elsif Quote::OPEN_STATUSES.include?(current_status) && quote.valid_until.present? && quote.valid_until < Date.current
        "expired"
      elsif first_view && Quote::AUTO_VIEW_STATUSES.include?(quote.status.to_s)
        "viewed"
      else
        quote.status
      end

    quote.update_columns(viewed_at: now, status: next_status, updated_at: Time.current)
  end
end
