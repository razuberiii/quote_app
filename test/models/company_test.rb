require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "new company seeds sample quote presets and master mapping" do
    company = Company.create!(name: "Seeder Co #{SecureRandom.hex(4)}")

    assert_equal QuotePreset::MODULE_KEYS.size, company.quote_presets.count
    QuotePreset::MODULE_KEYS.each do |module_key|
      assert company.quote_presets.where(module_key: module_key).exists?, "missing preset for #{module_key}"
    end

    master = company.quote_preset_master
    assert_not_nil master
    assert_not_nil master.business_terms_preset
    assert_not_nil master.advanced_trade_terms_preset
    assert_not_nil master.advanced_logistics_preset
    assert_not_nil master.container_loading_preset
    assert_not_nil master.configuration_block_preset
    assert_not_nil master.formal_closing_preset
  end
end
