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
    assert batch.product_import_candidates.all? { |candidate| candidate.decision == "create" }
    assert_equal "Sheet 1 · A2:F2", batch.product_import_candidates.first.evidence.first["location"]

    first = batch.product_import_candidates.first
    post apply_product_import_batch_path(batch), params: { candidates: {
      first.id.to_s => { decision: "create", candidate_data: first.candidate_data.merge("name" => "HPU 380 Confirmed") }
    } }
    assert_redirected_to library_path
    assert_equal 2, @user.company.products.count
    assert @user.company.products.exists?(name: "HPU 380 Confirmed")
    assert @user.company.products.exists?(name: "Dosing pump")
    assert_equal 2460, @user.company.products.find_by!(name: "HPU 380 Confirmed").default_price
  ensure
    file&.close!
  end

  test "applying a default review imports the complete batch" do
    batch = @user.company.product_import_batches.create!(
      created_by: @user, input_fingerprint: "review:untouched", status: "review"
    )
    batch.product_import_candidates.create!(
      candidate_data: { "name" => "Hydraulic unit", "sku" => "HU-1", "currency" => "元" },
      decision: "create"
    )
    batch.product_import_candidates.create!(
      candidate_data: { "name" => "Seal kit", "sku" => "SK-1", "currency" => "USD" },
      decision: "create"
    )

    assert_difference -> { @user.company.products.count }, 2 do
      post apply_product_import_batch_path(batch), params: { candidates: {} }
    end

    assert_redirected_to library_path
    assert_equal "applied", batch.reload.status
    assert_equal %w[imported imported], batch.product_import_candidates.order(:id).pluck(:decision)
    assert_equal "CNY", @user.company.products.find_by!(sku: "HU-1").price_currency
  end

  test "a partial review imports only explicit choices and remains reviewable" do
    batch = @user.company.product_import_batches.create!(
      created_by: @user, input_fingerprint: "review:partial", status: "review"
    )
    selected = batch.product_import_candidates.create!(
      candidate_data: { "name" => "Selected product", "sku" => "SEL-1" }, decision: "create"
    )
    deferred = batch.product_import_candidates.create!(
      candidate_data: { "name" => "Deferred product", "sku" => "DEF-1" }, decision: "pending"
    )

    assert_difference -> { @user.company.products.count }, 1 do
      post apply_product_import_batch_path(batch), params: { candidates: {
        selected.id.to_s => { decision: "create", candidate_data: selected.candidate_data },
        deferred.id.to_s => { decision: "pending", candidate_data: deferred.candidate_data }
      } }
    end

    assert_redirected_to product_import_batch_path(batch)
    assert_equal "review", batch.reload.status
    assert_equal "imported", selected.reload.decision
    assert_equal "pending", deferred.reload.decision
    assert @user.company.products.exists?(sku: "SEL-1")
    assert_not @user.company.products.exists?(sku: "DEF-1")
  end

  test "applying an entirely ignored review stays on review without a false success" do
    batch = @user.company.product_import_batches.create!(
      created_by: @user, input_fingerprint: "review:ignored", status: "review"
    )
    candidate = batch.product_import_candidates.create!(
      candidate_data: { "name" => "Do not import" }, decision: "pending"
    )

    assert_no_difference -> { @user.company.products.count } do
      post apply_product_import_batch_path(batch), params: {
        candidates: { candidate.id.to_s => { decision: "ignore", candidate_data: candidate.candidate_data } }
      }
    end

    assert_redirected_to product_import_batch_path(batch)
    assert_equal "review", batch.reload.status
    assert_equal "没有可导入的商品。请至少选择一个商品，或将不需要的商品设为忽略。", flash[:alert]
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
    assert_equal "create", batch.product_import_candidates.first.decision
    assert_equal "failed", batch.processing_report.first["status"]
  ensure
    ENV["OPENAI_API_KEY"] = original_api_key
    file&.close!
  end

  test "a repeated product without SKU defaults to merging by normalized name" do
    existing = @user.company.products.create!(name: "Dosing Pump", price_currency: "USD")
    file = Tempfile.new([ "repeat-product", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row [ "Product", "Unit price", "Currency" ]
      sheet.add_row [ "  Dosing Pump  ", 1200, "USD" ]
    end
    package.serialize(file.path)
    upload = Rack::Test::UploadedFile.new(
      file.path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: "repeat-product.xlsx"
    )

    perform_enqueued_jobs do
      post product_import_batches_path, params: { product_import_batch: { source_files: [ upload ] } }
    end

    candidate = @user.company.product_import_batches.order(:id).last.product_import_candidates.first
    assert_equal "merge", candidate.decision
    assert_equal existing, candidate.matched_product
  ensure
    file&.close!
  end

  test "processing batch renders a stable waiting page while the worker parses files" do
    batch = @user.company.product_import_batches.create!(created_by: @user,
      input_fingerprint: "processing:test", status: "processing")

    get product_import_batch_path(batch)

    assert_response :success
    assert_select "h1", text: "正在整理商品目录"
    assert_select "meta[http-equiv='refresh']", count: 0
    assert_select "[data-controller='catalog-processing']"
    assert_select ".candidate-review", count: 0

    get product_import_batch_path(batch, format: :json)
    assert_response :success
    assert_equal "processing", response.parsed_body["status"]
  end

  test "new import resumes an existing processing task" do
    batch = @user.company.product_import_batches.create!(created_by: @user,
      input_fingerprint: "processing:resume", status: "processing")

    get new_product_import_batch_path

    assert_redirected_to product_import_batch_path(batch)
  end

  test "active task endpoint exposes a stable return path and completion state" do
    batch = @user.company.product_import_batches.create!(created_by: @user,
      input_fingerprint: "review:ready", status: "review")
    batch.product_import_candidates.create!(candidate_data: { "name" => "Dosing pump" }, decision: "pending")

    get active_product_import_batches_path(format: :json)

    assert_response :success
    assert_equal batch.id, response.parsed_body["id"]
    assert_equal "review", response.parsed_body["status"]
    assert_equal 1, response.parsed_body["candidateCount"]
    assert_equal product_import_batch_path(batch), response.parsed_body["path"]
  end
end
