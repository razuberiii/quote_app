require "test_helper"

class QuoteCoreResourcesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "document design replaces template management" do
    get edit_document_design_path
    assert_response :success
    assert_select ".document-design"
    assert_select ".design-paper"

    get quote_templates_path
    assert_redirected_to edit_document_design_path
  end

  test "AI import hub exposes the four source categories" do
    get imports_path
    assert_response :success
    assert_select ".import-hub__row", 4
  end

  test "customer resource renders without CRM dashboard" do
    get customers_path
    assert_response :success
    assert_select ".customer-core"
    assert_select ".dashboard-module", 0
  end

  test "published versions expose direct PDF and Excel downloads" do
    revision = quotes(:one).quote_revisions.create!(company: companies(:one), number: 1, status: "current",
      currency: "USD", total: 100, snapshot: QuoteSnapshotBuilder.new(quotes(:one)).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    get quote_path(quotes(:one), tab: "versions")
    assert_response :success
    assert_select "a[href='#{quote_version_export_path(quotes(:one), revision, output: 'pdf')}']"
    assert_select "a[href='#{quote_version_export_path(quotes(:one), revision, output: 'excel')}']"
  end
end
