class QuoteReasonOption < ApplicationRecord
  KINDS = %w[win loss].freeze

  belongs_to :company

  validates :kind, inclusion: { in: KINDS }
  validates :key, presence: true
  validates :label, presence: true
  validates :key, uniqueness: { scope: [ :company_id, :kind ] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }
  scope :for_kind, ->(kind) { where(kind: kind.to_s) }

  before_validation :normalize_fields

  private

  def normalize_fields
    self.kind = kind.to_s
    self.label = label.to_s.strip
    self.key = key.to_s.strip.downcase
    self.key = generate_key_from_label if key.blank? && label.present?
    self.position = 0 if position.nil?
  end

  def generate_key_from_label
    base = label.to_s.parameterize(separator: "_")
    base = "reason" if base.blank?

    candidate = base
    suffix = 2
    while self.class.where(company_id: company_id, kind: kind, key: candidate).where.not(id: id).exists?
      candidate = "#{base}_#{suffix}"
      suffix += 1
    end

    candidate
  end
end
