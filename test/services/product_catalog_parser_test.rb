require "test_helper"

class ProductCatalogParserTest < ActiveSupport::TestCase
  Upload = Struct.new(:original_filename, :tempfile)

  test "extracts explicit CSV values and neutralizes formulas" do
    file = Tempfile.new([ "catalog", ".csv" ])
    file.write("Product,SKU,Unit price,Currency,Description\nPump X,PX-1,1250,USD,=1+1\n")
    file.rewind
    result = ProductCatalogParser.new([ Upload.new("catalog.csv", file) ]).call

    assert_equal "Pump X", result.products.first["name"]
    assert_equal 1250.0, result.products.first["explicit_price"]
    assert result.products.first["description"].start_with?("'")
    assert result.warnings.any? { |warning| warning.include?("中和") }
  ensure
    file&.close!
  end

  test "extracts multiple products and source cells from XLSX without AI" do
    require "axlsx"
    file = Tempfile.new([ "machinery-catalog", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Pumps") do |sheet|
      sheet.add_row [ "Product", "SKU", "Unit price", "Currency", "MOQ", "Lead time" ]
      sheet.add_row [ "Hydraulic power unit", "HPU-380", 2460, "USD", 2, "18 days" ]
      sheet.add_row [ "Gear dosing pump", "GDP-40", nil, "USD", 5, "12 days" ]
    end
    package.serialize(file.path)
    result = ProductCatalogParser.new([ Upload.new("machinery-catalog.xlsx", file) ]).call

    assert_equal 2, result.products.size
    assert_equal "HPU-380", result.products.first["sku"]
    assert_equal 2460.0, result.products.first["explicit_price"]
    assert_nil result.products.second["explicit_price"]
    assert_equal "Sheet 1 · A2:F2", result.products.first.dig("evidence", 0, "location")
    assert_not result.ai_required
    assert_equal "recognized", result.processing_report.first["status"]
  ensure
    file&.close!
  end

  test "does not invent missing prices" do
    file = Tempfile.new([ "catalog", ".csv" ])
    file.write("Product,SKU\nPump X,PX-1\n")
    file.rewind
    result = ProductCatalogParser.new([ Upload.new("catalog.csv", file) ]).call
    assert_nil result.products.first["explicit_price"]
  ensure
    file&.close!
  end


  test "retains page evidence from a real multi page PDF catalog for structured review" do
    html = <<~HTML
      <!doctype html><html><style>@page{size:A4;margin:20mm}.page{page-break-after:always}</style><body>
      <section class="page"><h1>Hydraulic Systems Catalog</h1><p>HPU-380 · 380V · MOQ 2</p></section>
      <section><h1>Dosing Pumps</h1><p>GDP-40 · Stainless steel · 12 day lead time</p></section>
      </body></html>
    HTML
    file = Tempfile.new([ "real-machinery-catalog", ".pdf" ])
    file.binmode
    file.write(ChromiumPdfRenderer.new(html).render)
    file.rewind

    result = ProductCatalogParser.new([ Upload.new("real-machinery-catalog.pdf", file) ]).call
    assert_empty result.products
    assert_includes result.ai_input, "第 1 页"
    assert_includes result.ai_input, "第 2 页"
    assert_includes result.ai_input, "HPU-380"
    assert_includes result.ai_input, "GDP-40"
    assert result.ai_required
    assert_equal [ "第 1 页", "第 2 页" ], result.processing_report.map { |range| range["location"] }
    assert result.warnings.any? { |warning| warning.include?("不会自动入库") }
  ensure
    file&.close!
  end


  test "unknown XLSX remains eligible for semantic analysis even when a deterministic row looks usable" do
    require "axlsx"
    file = Tempfile.new([ "unknown-layout", ".xlsx" ])
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row [ "Offer", "Ref", "Commercial" ]
      sheet.add_row [ "Pump X", "PX-1", "USD 1250" ]
    end
    package.serialize(file.path)
    result = ProductCatalogParser.new([ Upload.new("unknown-layout.xlsx", file) ]).call
    assert result.ai_required
    assert_equal "ai_required", result.processing_report.first["analysis"]
  ensure
    file&.close!
  end
end
