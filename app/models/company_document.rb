class CompanyDocument < ApplicationRecord
  DOCUMENT_TYPES = [
    "certificate",
    "company_profile",
    "product_brochure"
  ].freeze

  belongs_to :company
  has_one_attached :file

  before_validation :apply_defaults

  validates :title, presence: true
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :file_must_be_attached

  scope :ordered, -> { order(:document_type, :created_at) }

  def document_type_label
    document_type.to_s.humanize
  end

  private

  def apply_defaults
    self.document_type = document_type.presence || "company_profile"
    return if title.present? || !file.attached?

    base_name = file.filename.to_s.sub(/\.[^.]+\z/, "").tr("_-", " ").squish
    self.title = base_name.presence || "Company document"
  end

  def file_must_be_attached
    errors.add(:file, "must be attached") unless file.attached?
  end
end
