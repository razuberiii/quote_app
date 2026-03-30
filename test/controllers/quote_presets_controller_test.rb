require "test_helper"

class QuotePresetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in @user
  end

  test "index is successful" do
    get quote_presets_url
    assert_response :success
    assert_select "form[data-quote-preset-form='1']", count: 0
  end

  test "new is successful with selected module key" do
    get new_quote_preset_url(module_key: "formal_closing")
    assert_response :success
    assert_select "form[data-quote-preset-form='1'] input[name='quote_preset[module_key]'][value='formal_closing']"
  end

  test "create preset under current company" do
    assert_difference("QuotePreset.count", 1) do
      post quote_presets_url, params: {
        quote_preset: {
          module_key: "business_terms",
          name: "BT-A",
          position: 1,
          payload: {
            payment_term: "30/70",
            trade_term: "FOB"
          }
        }
      }
    end

    preset = QuotePreset.order(:created_at).last
    assert_equal @user.company_id, preset.company_id
    assert_redirected_to quote_presets_path(module_key: "business_terms")
  end

  test "invalid create renders new page" do
    post quote_presets_url, params: {
      quote_preset: {
        module_key: "business_terms",
        name: "",
        payload: {
          payment_term: "30/70",
          trade_term: "FOB"
        }
      }
    }

    assert_response :unprocessable_entity
    assert_select "form[data-quote-preset-form='1']"
  end

  test "cannot edit preset from another company" do
    external = @other_user.company.quote_presets.create!(
      module_key: "business_terms",
      name: "External",
      payload: { "payment_term" => "Net 30" }
    )

    get edit_quote_preset_url(external)
    assert_response :not_found
  end
end
