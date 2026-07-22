require "test_helper"

class CompanyProfileImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    company = Company.create!(name: "Original Trading", default_currency: "USD")
    @user = User.create!(company: company, company_role: :owner, username: "profile_reviewer",
      email: "profile-review@example.com", password: "password123", email_verified_at: Time.current)
    @profile_import = company.company_profile_imports.create!(created_by: @user, source_text: "Legal name: Confirmed Machinery Ltd.",
      status: "review", candidate_data: {
        "company" => { "name" => nil, "legal_name" => "Confirmed Machinery Ltd.", "email" => nil },
        "warnings" => [], "evidence" => []
      })
    sign_in @user
  end

  test "review save does not modify company" do
    patch company_profile_import_path(@profile_import), params: { company_profile_import: { candidate_data: { legal_name: "Reviewed Machinery Ltd." } } }

    assert_redirected_to company_profile_import_path(@profile_import)
    assert_equal "Original Trading", @user.company.reload.name
    assert_nil @user.company.legal_name
    assert_equal "Reviewed Machinery Ltd.", @profile_import.reload.candidate_data.dig("company", "legal_name")
  end

  test "apply writes confirmed values and blank candidates do not overwrite existing values" do
    @user.company.update!(email: "existing@example.com")
    patch apply_company_profile_import_path(@profile_import), params: { company_profile_import: { candidate_data: {
      legal_name: "Confirmed Machinery Ltd.", email: ""
    } } }

    assert_redirected_to edit_company_settings_path
    assert_equal "Confirmed Machinery Ltd.", @user.company.reload.legal_name
    assert_equal "existing@example.com", @user.company.email
    assert_equal "applied", @profile_import.reload.status
  end

  test "imports are isolated by company" do
    other_company = Company.create!(name: "Other Company")
    other_user = User.create!(company: other_company, company_role: :owner, username: "other_reviewer",
      email: "other-review@example.com", password: "password123", email_verified_at: Time.current)
    sign_out @user
    sign_in other_user

    get company_profile_import_path(@profile_import)
    assert_response :not_found
  end
end
