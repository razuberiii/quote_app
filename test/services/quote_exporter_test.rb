require "test_helper"

class QuoteExporterTest < ActiveSupport::TestCase
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

    assert_includes xml_text, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_match(/Shipping (&amp;|&) Logistics/, xml_text)
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
