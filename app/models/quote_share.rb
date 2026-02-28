class QuoteShare < ApplicationRecord
  belongs_to :company
  belongs_to :quote

  validates :token, presence: true, uniqueness: true
  validates :snapshot, presence: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.generate_token
    SecureRandom.hex(12)
  end

  def track_view!
    now = Time.current
    first_view = first_viewed_at.blank?
    update_sql = if first_view
      [ "view_count = view_count + 1, first_viewed_at = ?, last_viewed_at = ?", now, now ]
    else
      [ "view_count = view_count + 1, last_viewed_at = ?", now ]
    end

    self.class.where(id: id).update_all(update_sql)
    return unless quote.present?

    current_status = quote.status.to_s
    current_status = "draft" if current_status == "pending"
    next_status =
      if Quote::OPEN_STATUSES.include?(current_status) && quote.valid_until.present? && quote.valid_until < Date.current
        "expired"
      elsif first_view && Quote::AUTO_VIEW_STATUSES.include?(quote.status.to_s)
        "viewed"
      else
        quote.status
      end
    quote.update_columns(viewed_at: now, status: next_status)
  end
end
