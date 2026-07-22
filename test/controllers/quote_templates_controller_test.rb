require "test_helper"

class DocumentDesignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "document design updates the single company design profile" do
    company = @user.company
    design = company.quote_template_or_default

    patch document_design_path, params: { quote_template: {
      layout_type: "modern", layout_density: "compact", accent_color: "#146EF5",
      font_family: "Inter", logo_position: "left", show_logo: "1", show_images: "0",
      public_link_locale: "en", pdf_locale: "en", excel_locale: "en"
    } }

    assert_redirected_to edit_document_design_path
    assert_equal "modern", design.reload.layout_type
    assert_equal "compact", design.layout_density
    assert_equal "#146EF5", design.accent_color
    assert_not design.show_images?
  end
end
