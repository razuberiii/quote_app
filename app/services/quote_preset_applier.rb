class QuotePresetApplier
  class << self
    def apply_business_terms_default!(quote, company:)
      master = company.quote_preset_master
      return if master.blank?

      preset = master.business_terms_preset
      return if preset.blank?

      payload = preset.payload_data
      Quote::BUSINESS_PRESET_KEYS.each do |key|
        next unless payload[key].present?
        next if quote[key].present?

        quote[key] = payload[key]
      end
    end

    def apply_advanced_defaults_if_enabled!(quote, company:)
      return unless quote.advanced_mode

      master = company.quote_preset_master
      return if master.blank?

      apply_to_quote!(quote, master.advanced_trade_terms_preset, overwrite: false)
      apply_to_quote!(quote, master.advanced_logistics_preset, overwrite: false)
      apply_to_quote!(quote, master.container_loading_preset, overwrite: false)
      apply_to_quote!(quote, master.configuration_block_preset, overwrite: false)
      apply_to_quote!(quote, master.formal_closing_preset, overwrite: false)
    end

    def apply_to_quote!(quote, preset, overwrite: true)
      return if preset.blank?

      payload = preset.payload_data
      case preset.module_key
      when "business_terms"
        Quote::BUSINESS_PRESET_KEYS.each do |key|
          value = payload[key].to_s.squish
          next if value.blank?
          next if !overwrite && quote[key].present?

          quote[key] = value
        end
      when "advanced_trade_terms"
        hash = quote.advanced_trade_terms_state
        Quote::ADVANCED_TRADE_TERMS_KEYS.each do |key|
          value = payload[key].to_s.squish
          next if value.blank?
          next if !overwrite && hash[key].present?

          hash[key] = value
        end
        quote.advanced_trade_terms = hash
      when "advanced_logistics"
        hash = quote.advanced_logistics_state
        Quote::ADVANCED_LOGISTICS_KEYS.each do |key|
          value = payload[key].to_s.squish
          next if value.blank?
          next if !overwrite && hash[key].present?

          hash[key] = value
        end
        quote.advanced_logistics = hash
      when "configuration_block"
        current = quote.configuration_block_state
        if overwrite || configuration_block_blank?(current)
          quote.configuration_block = payload
        end
      when "container_loading"
        current = quote.container_loading_block_state
        if overwrite || container_loading_block_blank?(current)
          quote.container_loading_block = payload
        end
      when "formal_closing"
        current = quote.formal_closing_block_state
        if overwrite || formal_closing_block_blank?(current)
          quote.formal_closing_block = payload
        end
      end
    end

    private

    def configuration_block_blank?(block)
      source = block.is_a?(Hash) ? block : {}
      rows = Array(source["rows"])
      notes = source["notes"].to_s.squish
      rows.blank? && notes.blank?
    end

    def container_loading_block_blank?(block)
      source = block.is_a?(Hash) ? block : {}
      rows = Array(source["rows"])
      rows.blank?
    end

    def formal_closing_block_blank?(block)
      source = block.is_a?(Hash) ? block : {}
      source.except("buyer_signature_line_enabled").values.all?(&:blank?)
    end

    def merge_block(current, incoming, overwrite:)
      current_hash = current.is_a?(Hash) ? current.deep_dup : {}
      incoming_hash = incoming.is_a?(Hash) ? incoming.deep_dup : {}
      return incoming_hash if overwrite

      incoming_hash.each do |key, value|
        existing = current_hash[key]
        if existing.blank?
          current_hash[key] = value
        elsif existing.is_a?(Hash) && value.is_a?(Hash)
          current_hash[key] = value.merge(existing)
        elsif existing.is_a?(Array) && value.is_a?(Array) && existing.empty?
          current_hash[key] = value
        end
      end
      current_hash
    end
  end
end
