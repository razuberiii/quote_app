require "test_helper"
require "axlsx"

class ProductImportBatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    company = Company.create!(name: "Catalog Import Factory", default_currency: "USD")
    @user = User.create!(company: company, company_role: :owner, username: "catalog_reviewer",
      email: "catalog-review@example.com", password: "password123", email_verified_at: Time.current)
    sign_in @user
  end

  test "XLSX candidates remain reviewable and do not enter Library silently" do
    file = Tempfile.new([ "supplier-catalog", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Pumps") do |sheet|
      sheet.add_row [ "Product", "SKU", "Unit price", "Currency", "MOQ", "Lead time" ]
      sheet.add_row [ "Hydraulic power unit", "HPU-380", 2460, "USD", 2, "18 days" ]
      sheet.add_row [ "Dosing pump", "GDP-40", nil, "USD", 5, "12 days" ]
    end
    package.serialize(file.path)
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", original_filename: "supplier-catalog.xlsx")

    assert_no_difference -> { @user.company.products.count } do
      post product_import_batches_path, params: { product_import_batch: { source_files: [ upload ] } }
    end
    batch = @user.company.product_import_batches.order(:id).last
    assert_redirected_to product_import_batch_path(batch)
    assert_equal 2, batch.product_import_candidates.size
    assert_equal "Sheet 1 · A2:F2", batch.product_import_candidates.first.evidence.first["location"]

    first = batch.product_import_candidates.first
    post apply_product_import_batch_path(batch), params: { candidates: {
      first.id.to_s => { decision: "create", candidate_data: first.candidate_data.merge("name" => "HPU 380 Confirmed") }
    } }
    assert_redirected_to library_path
    assert_equal 2, @user.company.products.count
    assert @user.company.products.exists?(name: "HPU 380 Confirmed")
  ensure
    file&.close!
  end
end
