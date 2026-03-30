require "test_helper"

class QuoteExporterTest < ActiveSupport::TestCase
  test "xlsx item description suppresses duplicated description line when normalized text matches title" do
    quote = quotes(:one)
    item = quote.quote_items.first
    item.update!(description: "Demo   Vehicle  ")
    product = products(:one)
    product.update!(name: "demo vehicle")
    item.update!(product: product)

    exporter = QuoteExporter.new(quote, template: quote.template || quote.company.quote_template_or_default)
    text = exporter.send(:excel_item_description_text, item)

    lines = text.split("\n").map(&:strip).reject(&:blank?)
    assert_equal "demo vehicle", lines.first
    assert_equal 1, lines.count { |line| line.casecmp("demo vehicle").zero? }
  end

  test "xlsx sections follow fixed order and include dedicated container loading section table" do
    require "zip"

    quote = quotes(:one)
    template = quote.template || quote.company.quote_template_or_default
    template.update!(show_scope_of_supply: true)
    detail_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image content"),
      filename: "detail-excel.png",
      content_type: "image/png"
    )
    quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      configuration_block: {
        "enabled" => true,
        "rows" => [ { "label" => "Motor", "value" => "120 kW PMSM", "position" => 1 } ]
      },
      detail_pictures_block: {
        "enabled" => true,
        "items" => [ { "image_blob_id" => detail_blob.id.to_s, "caption" => "Controller panel", "position" => 1 } ]
      },
      advanced_logistics: {
        "freight_note" => "Weekly vessel",
        "container_loading_note" => "Legacy note should not replace table"
      },
      container_loading_block: {
        "enabled" => true,
        "rows" => [ { "variant" => "LHD Standard", "container_type" => "40HQ", "capacity" => "2 units", "note" => "With wheel chocks", "position" => 1 } ]
      },
      scope_of_supply: "EV unit\nInspection report",
      formal_closing_block: {
        "trade_term" => "FOB Shanghai",
        "payment_term" => "T/T 30/70",
        "delivery_time" => "Within 30 days",
        "bank_route" => "BKCHCNBJ300"
      },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    exporter = QuoteExporter.new(quote, template: quote.template || quote.company.quote_template_or_default)
    xlsx_binary = exporter.to_xlsx.to_stream.read
    xml_text = +""
    Zip::File.open_buffer(StringIO.new(xlsx_binary)) do |zip|
      zip.glob("xl/**/*.xml").each do |entry|
        xml_text << entry.get_input_stream.read
      end
    end

    logistics_token = xml_text.include?("SHIPPING &amp; LOGISTICS") ? "SHIPPING &amp; LOGISTICS" : "SHIPPING & LOGISTICS"
    order = [
      "TRADE TERMS",
      "CONFIGURATION",
      "DETAIL PICTURES",
      logistics_token,
      "CONTAINER LOADING",
      "SCOPE OF SUPPLY",
      "FORMAL CLOSING"
    ].map { |token| xml_text.index(token) }
    assert order.all?
    assert_equal order.sort, order
    assert_includes xml_text, "Variant / Trim"
    assert_includes xml_text, "Container Type"
    assert_includes xml_text, "Load Capacity"
    assert_includes xml_text, "Loading Note"
    assert_includes xml_text, "LHD Standard"
    assert_not_includes xml_text, "Container Loading: Legacy note should not replace table"
  end

  test "advanced section labels are readable in exporter helpers" do
    quote = quotes(:one)
    quote.update!(
      advanced_mode: true,
      advanced_trade_terms: {
        "hs_code" => "8703.10",
        "payment_clause_note" => "30% deposit"
      },
      advanced_logistics: {
        "container_type" => "40HQ",
        "freight_note" => "Sea freight included"
      },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    exporter = QuoteExporter.new(quote, template: quote.template || quote.company.quote_template_or_default)

    trade_lines = exporter.send(:advanced_trade_terms_lines)
    logistics_lines = exporter.send(:advanced_logistics_lines)

    assert_includes trade_lines, [ I18n.t("quotes.view.form.hs_code", default: "HS Code"), "8703.10" ]
    assert_includes trade_lines, [ I18n.t("quotes.view.show.field_labels.payment_terms", default: "Payment Terms"), "30% deposit" ]
    assert_includes logistics_lines, [ I18n.t("quotes.view.show.field_labels.container_type", default: "Container Type"), "40HQ" ]
    assert_includes logistics_lines, [ I18n.t("quotes.view.show.field_labels.freight", default: "Freight"), "Sea freight included" ]
  end

  test "xlsx supplementary section headings are customer-facing" do
    require "zip"

    quote = quotes(:one)
    quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    exporter = QuoteExporter.new(quote, template: quote.template || quote.company.quote_template_or_default)
    xlsx_binary = exporter.to_xlsx.to_stream.read
    xml_text = +""
    Zip::File.open_buffer(StringIO.new(xlsx_binary)) do |zip|
      zip.glob("xl/**/*.xml").each do |entry|
        xml_text << entry.get_input_stream.read
      end
    end

    assert_includes xml_text, "TRADE TERMS"
    assert_match(/SHIPPING (&amp;|&) LOGISTICS/, xml_text)
    assert_not_includes xml_text, "Advanced Trade Terms"
    assert_not_includes xml_text, "Advanced Logistics"
  end

  test "prawn supplementary section titles stay customer-facing" do
    quote = quotes(:one)
    quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    exporter = QuoteExporter.new(quote, template: quote.template || quote.company.quote_template_or_default)

    assert_equal I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms"), exporter.send(:supplementary_trade_terms_title)
    assert_equal I18n.t("quotes.view.show.shipping_and_logistics", default: "Shipping & Logistics"), exporter.send(:shipping_and_logistics_title)
  end
end
