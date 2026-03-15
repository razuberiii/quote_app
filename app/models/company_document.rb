class CompanyDocument < ApplicationRecord
  DOCUMENT_TYPES = [
    "certificate",
    "company_profile",
    "product_brochure"
  ].freeze
  ALLOWED_FILE_CONTENT_TYPES = %w[
    application/pdf
    image/png
    image/jpeg
    image/webp
    text/plain
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.ms-powerpoint
  ].freeze
  MAX_FILE_SIZE = 15.megabytes
  MAX_DOCUMENTS_PER_COMPANY = 80

  belongs_to :company
  has_one_attached :file

  before_validation :apply_defaults

  validates :title, presence: true
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validate :file_must_be_attached
  validate :file_constraints
  validate :company_document_count_limit, on: :create

  scope :ordered, -> { order(:document_type, :created_at) }

  def document_type_label
    I18n.t(
      "company_settings.view.edit.credential_types.#{document_type}",
      default: document_type.to_s.humanize
    )
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

  def file_constraints
    return unless file.attached?

    if !ALLOWED_FILE_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "type is not allowed")
    end
    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end

  def company_document_count_limit
    return if company.blank?
    return if company.company_documents.where.not(id: id).count < MAX_DOCUMENTS_PER_COMPANY

    errors.add(:base, "document limit reached (max #{MAX_DOCUMENTS_PER_COMPANY})")
  end
end
