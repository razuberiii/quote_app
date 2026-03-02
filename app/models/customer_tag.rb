class CustomerTag < ApplicationRecord
  PRESET_NAMES = ["VIP", "Distributor", "High Potential", "Risky", "Long-term"].freeze

  belongs_to :company
  has_many :customer_taggings, dependent: :destroy
  has_many :customers, through: :customer_taggings

  validates :name, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }

  before_validation :normalize_name

  scope :ordered, -> { order(:name) }

  def self.ensure_presets_for(company)
    PRESET_NAMES.each do |name|
      company.customer_tags.find_or_create_by!(name: name)
    end
  end

  private

  def normalize_name
    self.name = name.to_s.strip.gsub(/\s+/, " ")
  end
end
