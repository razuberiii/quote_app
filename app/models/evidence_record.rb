class EvidenceRecord < ApplicationRecord
  belongs_to :company
  belongs_to :source_record, polymorphic: true
  belongs_to :ai_analysis, optional: true

  validates :evidence_key, :excerpt, presence: true
  validates :confidence, numericality: { in: 0..1 }, allow_nil: true
end
