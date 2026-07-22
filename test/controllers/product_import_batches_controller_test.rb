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
      perform_enqueued_jobs do
        post product_import_batches_path, params: { product_import_batch: { source_files: [ upload ] } }
      end
    end
    batch = @user.company.product_import_batches.order(:id).last
    assert_redirected_to product_import_batch_path(batch)
    assert_equal 2, batch.product_import_candidates.size
    assert batch.product_import_candidates.all? { |candidate| candidate.decision == "pending" }
    assert_equal "Sheet 1 · A2:F2", batch.product_import_candidates.first.evidence.first["location"]

    first = batch.product_import_candidates.first
    post apply_product_import_batch_path(batch), params: { candidates: {
      first.id.to_s => { decision: "create", candidate_data: first.candidate_data.merge("name" => "HPU 380 Confirmed") }
    } }
    assert_redirected_to library_path
    assert_equal 1, @user.company.products.count
    assert @user.company.products.exists?(name: "HPU 380 Confirmed")
    assert_equal 2460, @user.company.products.find_by!(name: "HPU 380 Confirmed").default_price
  ensure
    file&.close!
  end


  test "unknown XLSX keeps deterministic candidates when semantic provider fails" do
    file = Tempfile.new([ "unknown-supplier", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row [ "Product", "Odd commercial column" ]
      sheet.add_row [ "Dosing pump", "contact supplier" ]
    end
    package.serialize(file.path)
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", original_filename: "unknown.xlsx")

    original_api_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = nil
    perform_enqueued_jobs do
      post product_import_batches_path, params: { product_import_batch: { source_files: [ upload ] } }
    end

    batch = @user.company.product_import_batches.order(:id).last
    assert_redirected_to product_import_batch_path(batch)
    assert_equal [ "Dosing pump" ], batch.product_import_candidates.map { |candidate| candidate.candidate_data["name"] }
    assert_equal "pending", batch.product_import_candidates.first.decision
    assert_equal "failed", batch.processing_report.first["status"]
  ensure
    ENV["OPENAI_API_KEY"] = original_api_key
    file&.close!
  end

  test "processing batch renders a stable waiting page while the worker parses files" do
    batch = @user.company.product_import_batches.create!(created_by: @user,
      input_fingerprint: "processing:test", status: "processing")

    get product_import_batch_path(batch)

    assert_response :success
    assert_select "h1", text: "正在整理商品目录"
    assert_select "meta[http-equiv='refresh'][content='3']"
    assert_select ".candidate-review", count: 0
  end
end
