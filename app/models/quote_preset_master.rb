class QuotePresetMaster < ApplicationRecord
  MODULE_PRESET_REFLECTIONS = {
    "business_terms" => :business_terms_preset,
    "advanced_trade_terms" => :advanced_trade_terms_preset,
    "advanced_logistics" => :advanced_logistics_preset,
    "container_loading" => :container_loading_preset,
    "configuration_block" => :configuration_block_preset,
    "formal_closing" => :formal_closing_preset
  }.freeze

  belongs_to :company
  belongs_to :business_terms_preset, class_name: "QuotePreset", optional: true
  belongs_to :advanced_trade_terms_preset, class_name: "QuotePreset", optional: true
  belongs_to :advanced_logistics_preset, class_name: "QuotePreset", optional: true
  belongs_to :container_loading_preset, class_name: "QuotePreset", optional: true
  belongs_to :configuration_block_preset, class_name: "QuotePreset", optional: true
  belongs_to :formal_closing_preset, class_name: "QuotePreset", optional: true

  validates :company_id, uniqueness: true
  validate :presets_belong_to_company
  validate :preset_module_must_match

  def preset_for(module_key)
    reflection = MODULE_PRESET_REFLECTIONS[module_key.to_s]
    reflection.present? ? public_send(reflection) : nil
  end

  private

  def presets_belong_to_company
    MODULE_PRESET_REFLECTIONS.values.each do |association_name|
      preset = public_send(association_name)
      next if preset.blank?
      next if preset.company_id == company_id

      errors.add(association_name, "must belong to current company")
    end
  end

  def preset_module_must_match
    MODULE_PRESET_REFLECTIONS.each do |module_key, association_name|
      preset = public_send(association_name)
      next if preset.blank?
      next if preset.module_key == module_key

      errors.add(association_name, "module mismatch")
    end
  end
end
