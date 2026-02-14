require "test_helper"

class QuoteTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "set_default switches default template and rebinds old default quotes" do
    company = @user.company
    old_default = company.quote_templates.first
    old_default.update!(default_template: true)

    replacement = company.quote_templates.create!(
      name: "Modern Template",
      slug: "modern-template",
      layout_type: "modern",
      accent_color: "#1F4E79",
      font_family: "Noto Sans",
      show_logo: true,
      show_images: true,
      show_tax: true,
      show_shipping: true,
      show_currency: true,
      show_valid_until: true,
      show_payment_term: true,
      show_terms_section: true,
      show_notes: true,
      show_product_images: true,
      show_signature_block: false,
      show_negotiated_flag: false,
      document_kind: "quotation"
    )

    quote = company.quotes.first
    quote.update_column(:template_id, old_default.id)

    patch set_default_quote_template_url(replacement)
    assert_redirected_to quote_templates_path

    assert replacement.reload.default_template?
    assert_not old_default.reload.default_template?
    assert_equal replacement.id, quote.reload.template_id
  end
end
