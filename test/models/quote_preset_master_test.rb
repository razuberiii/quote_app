require "test_helper"

class QuotePresetMasterTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    @other_company = companies(:two)
  end

  test "company has only one master" do
    @company.create_quote_preset_master!
    second = QuotePresetMaster.new(company: @company)

    assert_not second.valid?
    assert_includes second.errors[:company_id], "has already been taken"
  end

  test "preset module must match configured slot" do
    wrong_preset = @company.quote_presets.create!(
      module_key: "advanced_logistics",
      name: "Logistics",
      payload: { "freight_note" => "By sea" }
    )

    master = @company.build_quote_preset_master(
      business_terms_preset: wrong_preset
    )

    assert_not master.valid?
    assert_includes master.errors[:business_terms_preset], "module mismatch"
  end

  test "preset must belong to same company" do
    external = @other_company.quote_presets.create!(
      module_key: "business_terms",
      name: "External",
      payload: { "payment_term" => "Net 30" }
    )

    master = @company.build_quote_preset_master(
      business_terms_preset: external
    )

    assert_not master.valid?
    assert_includes master.errors[:business_terms_preset], "must belong to current company"
  end
end
