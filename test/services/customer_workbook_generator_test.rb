require "test_helper"
require "zip"

class CustomerWorkbookGeneratorTest < ActiveSupport::TestCase
  test "fills a customer workbook while preserving mapped cell styles" do
    quote = quotes(:one)
    template = build_template(quote.company)
    quote.update!(workbook_template: template, custom_field_values: { "project_code" => "=PRJ-42" })
    revision = quote.quote_revisions.create!(company: quote.company, number: quote.quote_revisions.maximum(:number).to_i + 1,
      status: "current", currency: quote.currency, total: quote.grand_total,
      snapshot: QuoteSnapshotBuilder.new(quote).as_json, secure_token: SecureRandom.urlsafe_base64(16),
      published_at: Time.current, expires_at: 30.days.from_now)

    output = CustomerWorkbookGenerator.new(revision, template).generate
    xml = nil
    Zip::File.open_buffer(output.io.read) { |zip| xml = zip.read("xl/worksheets/sheet1.xml") }
    document = Nokogiri::XML(xml)
    document.remove_namespaces!

    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", output.content_type
    assert_equal quote.quote_no, cell_text(document, "B2")
    assert_equal quote.customer.name, cell_text(document, "B3")
    assert_equal "=PRJ-42", cell_text(document, "B4")
    assert_equal quote.quote_items.first.description, cell_text(document, "B10")
    assert_equal "3", document.at_xpath("//c[@r='B2']")["s"], "the customer's cell style is retained"
  end

  private

  def build_template(company)
    package = Axlsx::Package.new
    sheet = package.workbook.add_worksheet(name: "Quote")
    style = package.workbook.styles.add_style(b: true, bg_color: "1F4E79", fg_color: "FFFFFF")
    sheet.add_row [ "Customer template" ]
    sheet.add_row [ "Quote", "" ], style: [ nil, style ]
    sheet.add_row [ "Customer", "" ]
    sheet.add_row [ "Project", "" ]
    5.times { sheet.add_row [] }
    sheet.add_row [ "SKU", "Description", "Qty", "Unit", "Unit price", "Amount" ]
    template = company.workbook_templates.new(name: "Customer blue form",
      field_mappings: { "quote_number" => "B2", "customer_name" => "B3" },
      item_mapping: { "sheet" => "Quote", "start_row" => 10, "columns" => { "sku" => "A", "description" => "B", "quantity" => "C", "unit" => "D", "unit_price" => "E", "amount" => "F" } },
      custom_fields: [ { "key" => "project_code", "label" => "Project code", "cell" => "B4", "required" => true } ])
    template.workbook.attach(io: StringIO.new(package.to_stream.read), filename: "customer.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    template.save!
    template
  end

  def cell_text(document, reference)
    cell = document.at_xpath("//c[@r='#{reference}']")
    cell&.at_xpath("./is/t|./v")&.text
  end
end
