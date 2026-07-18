class AiAnalysis < ApplicationRecord
  STATUSES = %w[validated invalid failed].freeze

  belongs_to :company
  belongs_to :source_record, polymorphic: true
  has_many :evidence_records, dependent: :restrict_with_exception

  validates :analysis_type, :provider, :model, :schema_version, :input_fingerprint, presence: true
  validates :status, inclusion: { in: STATUSES }
end
