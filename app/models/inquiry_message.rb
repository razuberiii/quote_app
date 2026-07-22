class InquiryMessage < ApplicationRecord
  DIRECTIONS = %w[buyer seller internal].freeze
  CHANNELS = %w[text email whatsapp wechat line phone meeting file other].freeze

  belongs_to :inquiry, touch: true
  belongs_to :recorded_by, class_name: "User", optional: true
  has_one_attached :attachment

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :channel, inclusion: { in: CHANNELS }
  validates :occurred_at, presence: true
  validate :body_or_attachment

  private

  def body_or_attachment
    errors.add(:body, :blank) if body.blank? && !attachment.attached?
  end
end
