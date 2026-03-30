require "test_helper"

class QuotePresetMastersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @business = @user.company.quote_presets.create!(
      module_key: "business_terms",
      name: "Master Business",
      payload: { "payment_term" => "30/70" }
    )
  end

  test "updates company master mapping" do
    patch quote_preset_master_url, params: {
      quote_preset_master: {
        business_terms_preset_id: @business.id
      }
    }

    assert_redirected_to quote_presets_path
    master = @user.company.reload.quote_preset_master
    assert_equal @business.id, master.business_terms_preset_id
  end
end
