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
    assert result.warnings.any? { |warning| warning.include?("neutralized") }
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
end
