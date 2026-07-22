class CompanyProfileImport < ApplicationRecord
  STATUSES = %w[draft review applied failed].freeze
  COMPANY_FIELDS = %w[name legal_name registration_number registration_details email phone address website business_type].freeze
  SOURCE_CONTENT_TYPES = %w[application/pdf text/plain text/csv application/csv].freeze
  MAX_SOURCE_SIZE = 15.megabytes

  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true
  has_one_attached :source_file

  validates :status, inclusion: { in: STATUSES }
  validate :source_present, on: :create
  validate :source_file_constraints

  private

  def source_present
    errors.add(:base, I18n.t("self_service.company_import.errors.source_required")) if source_text.blank? && !source_file.attached?
  end

  def source_file_constraints
    return unless source_file.attached?

    errors.add(:source_file, I18n.t("self_service.company_import.errors.file_type")) unless SOURCE_CONTENT_TYPES.include?(source_file.blob.content_type)
    errors.add(:source_file, I18n.t("self_service.company_import.errors.file_size")) if source_file.blob.byte_size > MAX_SOURCE_SIZE
  end
end
