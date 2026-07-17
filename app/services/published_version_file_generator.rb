require "stringio"

class PublishedVersionFileGenerator
  Result = Data.define(:io, :filename, :content_type, :byte_size)

  def initialize(revision)
    @revision = revision
    raise ArgumentError, "A Published Version is required" if revision.published_at.blank?
  end

  def pdf
    html = BuyerRoomsController.render(
      template: "buyer_rooms/pdf", layout: "pdf", formats: [ :html ],
      assigns: { revision: @revision, snapshot: @revision.snapshot }
    )
    binary = ChromiumPdfRenderer.new(html).render
    result(binary, "#{base_name}.pdf", "application/pdf")
  end

  def excel
    require "axlsx"
    package = Axlsx::Package.new
    workbook = package.workbook
    money = workbook.styles.add_style(format_code: "#,##0.00", num_fmt: 4)
    header = workbook.styles.add_style(b: true, bg_color: "121620", fg_color: "FFFFFF")
    sheet = workbook.add_worksheet(name: "Published quote")
    sheet.add_row [ "Rubusoo Published Version", nil, nil, nil, nil, nil, nil, nil ], style: header
    sheet.add_row [ "Deal ID", @revision.quote_id, "Version ID", @revision.id, "Quote", safe(@revision.quote.quote_no), "Version", @revision.number ]
    sheet.add_row [ "Buyer", safe(@revision.snapshot["customer_name"]), "Currency", safe(@revision.currency), "Published", @revision.published_at.iso8601 ]
    sheet.add_row []
    sheet.add_row %w[Line_ID SKU Description Specifications Quantity Unit Unit_price Discount Amount], style: header
    Array(@revision.snapshot["quote_items"]).each_with_index do |item, index|
      quantity = item["quantity"].to_d
      unit_price = item["unit_price"].to_d
      discount = item["discount_amount"].to_d
      specs = Array(item["specifications"]).map { |spec| "#{spec['key'] || spec['name']}: #{spec['value']}" }.join(" | ")
      sheet.add_row [ item["id"].presence || "line-#{index + 1}", safe(item["sku_snapshot"]), safe(item["description"]), safe(specs), quantity,
        safe(item["unit_snapshot"]), unit_price, discount, (quantity * unit_price) - discount ],
        style: [ nil, nil, nil, nil, nil, nil, money, money, money ]
    end
    sheet.add_row []
    %w[shipping_amount discount_amount tax_amount].each { |key| sheet.add_row [ key.humanize, @revision.snapshot[key].to_d ], style: [ nil, money ] }
    sheet.add_row [ "Total", @revision.total ], style: [ header, money ]
    sheet.add_row [ "Incoterm", safe(@revision.snapshot["trade_term"]) ]
    sheet.add_row [ "Payment terms", safe(@revision.snapshot["payment_term"]) ]
    sheet.add_row [ "Delivery terms", safe(@revision.snapshot["delivery_notes"]) ]
    sheet.column_widths 8, 18, 34, 48, 12, 12, 16, 14, 16

    metadata = workbook.add_worksheet(name: "Rubusoo metadata")
    metadata.state = :hidden
    metadata.add_row [ "deal_id", @revision.quote_id ]
    metadata.add_row [ "version_id", @revision.id ]
    metadata.add_row [ "version_number", @revision.number ]
    metadata.add_row [ "secure_fingerprint", Digest::SHA256.hexdigest(canonical(@revision.snapshot).to_json) ]
    binary = package.to_stream.read
    result(binary, "#{base_name}.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end

  private

  def safe(value)
    text = value.to_s
    text.match?(/\A[=+\-@]/) ? "'#{text}" : text
  end

  def result(binary, filename, content_type)
    Result.new(StringIO.new(binary), filename, content_type, binary.bytesize)
  end

  def base_name
    "#{@revision.quote.quote_no}-V#{@revision.number}"
  end

  def canonical(value)
    return value.keys.sort.to_h { |key| [ key, canonical(value[key]) ] } if value.is_a?(Hash)
    return value.map { |entry| canonical(entry) } if value.is_a?(Array)
    value
  end
end
