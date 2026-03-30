class QuotePresetSampleSeeder
  SAMPLE_PRESETS = {
    "business_terms" => {
      name: "Sample FT - Business Core",
      payload: {
        "payment_term" => "T/T 30% deposit, 70% against copy of B/L.",
        "trade_term" => "FOB Shanghai",
        "delivery_notes" => "Production lead time: 25-30 days after deposit and artwork confirmation.",
        "terms_text" => "Quotation validity: 15 days from issue date. Final packing list and invoice follow approved order details.",
        "scope_of_supply" => "Unit complete with standard accessory kit, user manual, and routine spare-parts package."
      }
    },
    "advanced_trade_terms" => {
      name: "Sample FT - Trade Addendum",
      payload: {
        "hs_code" => "8703.10",
        "warranty_scope_note" => "12-month vehicle warranty; battery warranty follows supplier policy.",
        "support_scope_note" => "Remote troubleshooting and spare-parts guidance included.",
        "validity_clause_note" => "Offer remains valid for 15 calendar days from quotation date.",
        "delivery_commitment_note" => "Standard lead time is 25-30 days after deposit confirmation.",
        "payment_clause_note" => "Bank handling charges outside China are borne by buyer."
      }
    },
    "advanced_logistics" => {
      name: "Sample FT - Logistics Addendum",
      payload: {
        "freight_note" => "Ocean freight is based on latest carrier schedule and confirmed booking window.",
        "container_type" => "40HQ",
        "shipping_scope_note" => "Port-to-port freight only. Destination customs, tax, and local charges are excluded.",
        "container_loading_note" => "Container loading plan follows approved unit mix and packing method."
      }
    },
    "standard_fee_items" => {
      name: "Sample FT - Standard Logistics Fees",
      payload: {
        "rows" => [
          { "name" => "Shipping Cost (40HQ, Port-to-Port)", "unit_price" => "5700.00", "quantity" => 1, "position" => 1 },
          { "name" => "Packing Surcharge (Wooden Crate)", "unit_price" => "380.00", "quantity" => 1, "position" => 2 },
          { "name" => "Dangerous Goods Handling Surcharge", "unit_price" => "240.00", "quantity" => 1, "position" => 3 },
          { "name" => "Port Service / Local Handling Fee", "unit_price" => "160.00", "quantity" => 1, "position" => 4 }
        ]
      }
    },
    "container_loading" => {
      name: "Sample FT - Container Loading",
      payload: {
        "headers" => Quote::DEFAULT_CONTAINER_LOADING_HEADERS,
        "note_enabled" => true,
        "rows" => [
          {
            "variant" => "14 seats without windows",
            "container_type" => "40HQ",
            "capacity" => "4 units",
            "note" => "Standard loading",
            "position" => 1
          },
          {
            "variant" => "17 seats with windows",
            "container_type" => "40HQ",
            "capacity" => "2 units",
            "note" => "With protective wooden crate",
            "position" => 2
          }
        ]
      }
    },
    "configuration_block" => {
      name: "Sample FT - Configuration Summary",
      payload: {
        "rows" => [
          { "label" => "Motor", "value" => "72V 7.5kW AC", "position" => 1 },
          { "label" => "Battery", "value" => "LiFePO4 210Ah", "position" => 2 }
        ]
      }
    },
    "formal_closing" => {
      name: "Sample FT - Formal Closing",
      payload: {
        "pi_number" => "PI-2026-0001",
        "payment_term" => "T/T 30/70",
        "trade_term" => "FOB Shanghai",
        "delivery_time" => "Within 30 days after deposit confirmation",
        "bank_route" => "BANK OF CHINA SHANGHAI BRANCH, SWIFT: BKCHCNBJ300",
        "beneficiary_details" => "Beneficiary: Rubusoo Trading Co., Ltd.",
        "remittance_note" => "Please indicate PI number in remittance remark.",
        "buyer_signature_line_enabled" => true
      }
    }
  }.freeze

  class << self
    def seed_for!(company)
      return if company.blank?

      presets = {}

      QuotePreset.transaction do
        QuotePreset::MODULE_KEYS.each do |module_key|
          sample = SAMPLE_PRESETS[module_key]
          next if sample.blank?

          existing = company.quote_presets.where(module_key: module_key).order(:position, :created_at).first
          presets[module_key] =
            if existing.present?
              existing
            else
              company.quote_presets.create!(
                module_key: module_key,
                name: sample[:name],
                position: 0,
                payload: sample[:payload]
              )
            end
        end

        master = company.quote_preset_master || company.build_quote_preset_master
        master.business_terms_preset ||= presets["business_terms"]
        master.advanced_trade_terms_preset ||= presets["advanced_trade_terms"]
        master.advanced_logistics_preset ||= presets["advanced_logistics"]
        master.container_loading_preset ||= presets["container_loading"]
        master.configuration_block_preset ||= presets["configuration_block"]
        master.formal_closing_preset ||= presets["formal_closing"]
        master.save!
      end
    end
  end
end
