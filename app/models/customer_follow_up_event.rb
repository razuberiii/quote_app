class CustomerFollowUpEvent < ApplicationRecord
  CHANNELS = %w[manual whatsapp email call linkedin].freeze

  belongs_to :customer
  belongs_to :user
  belongs_to :quote, optional: true

  before_validation :set_defaults

  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :contacted_at, presence: true

  scope :recent_first, -> { order(contacted_at: :desc, created_at: :desc) }

  def channel_label
    I18n.t("follow_up.channels.#{channel}", default: channel.to_s.humanize)
  end

  private

  def set_defaults
    self.channel = channel.to_s.presence || "manual"
    self.contacted_at ||= Time.current
    self.metadata = {} if metadata.blank?
  end
end
