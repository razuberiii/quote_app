require "test_helper"

class WorkbookTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "owner uploads an xlsx with core item and custom mappings" do
    upload = workbook_upload

    assert_difference("WorkbookTemplate.count") do
      post workbook_templates_path, params: {
        workbook_template: { name: "Buyer form", workbook: upload,
          custom_fields_text: "project_code | 项目编号 | B6 | required" },
        core_mappings: { quote_number: "b3", total: "f20" },
        item_mapping: { sheet: "Quote", start_row: "10", description: "b", quantity: "c", amount: "f" }
      }
    end

    template = WorkbookTemplate.order(:created_at).last
    assert_redirected_to workbook_templates_path
    assert_equal "B3", template.field_mappings["quote_number"]
    assert_equal "B", template.item_mapping.dig("columns", "description")
    assert_equal "project_code", template.custom_fields.first["key"]
  ensure
    upload&.tempfile&.close!
  end

  test "renamed non-xlsx content is rejected" do
    file = Tempfile.new([ "fake", ".xlsx" ])
    file.write("not a zip package")
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", true)

    assert_no_difference("WorkbookTemplate.count") do
      post workbook_templates_path, params: { workbook_template: { name: "Unsafe", workbook: upload }, item_mapping: {} }
    end

    assert_response :unprocessable_entity
    assert_match "valid Excel", response.body
  ensure
    file&.close!
  end

  test "quote studio lists company workbook templates" do
    template = users(:one).company.workbook_templates.new(name: "Procurement form")
    template.workbook.attach(io: StringIO.new(workbook_binary), filename: "procurement.xlsx")
    template.save!

    get quote_path(quotes(:one))

    assert_response :success
    assert_select "select[name='quote[workbook_template_id]'] option", text: "Procurement form"
  end

  test "published quote downloads its frozen customer workbook" do
    quote = quotes(:one)
    template = quote.company.workbook_templates.new(name: "Frozen buyer form",
      field_mappings: { "quote_number" => "B2" }, item_mapping: {}, custom_fields: [])
    template.workbook.attach(io: StringIO.new(workbook_binary), filename: "buyer.xlsx")
    template.save!
    quote.update!(workbook_template: template)
    revision = quote.quote_revisions.create!(company: quote.company, number: quote.quote_revisions.maximum(:number).to_i + 1,
      status: "current", currency: quote.currency, total: quote.grand_total,
      snapshot: QuoteSnapshotBuilder.new(quote).as_json, secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    get quote_version_export_path(quote, revision, output: "customer_excel")

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert response.body.start_with?("PK")
  end

  private

  def workbook_upload
    file = Tempfile.new([ "customer-template", ".xlsx" ])
    file.binmode
    file.write(workbook_binary)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", true)
  end

  def workbook_binary
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Quote") { |sheet| sheet.add_row [ "Quotation" ] }
    package.to_stream.read
  end
end
