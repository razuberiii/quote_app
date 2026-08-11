require "stringio"

class PublishedVersionFileGenerator
  Result = Data.define(:io, :filename, :content_type, :byte_size)

  def initialize(revision)
    @revision = revision
    raise ArgumentError, "A Published Version is required" if revision.published_at.blank?
  end

  def pdf
    html = I18n.with_locale(design["pdf_locale"].presence || buyer_locale) do
      BuyerRoomsController.render(
        template: "buyer_rooms/pdf", layout: "pdf", formats: [ :html ],
        assigns: { revision: @revision, snapshot: @revision.snapshot }
      )
    end
    binary = ChromiumPdfRenderer.new(html).render
    result(binary, "#{base_name}.pdf", "application/pdf")
  end

  def excel
    require "axlsx"
    package = Axlsx::Package.new
    workbook = package.workbook
    accent = design.fetch("accent_color", "#1F4E79").delete_prefix("#")
    money = workbook.styles.add_style(format_code: "#,##0.00", num_fmt: 4, alignment: { horizontal: :right })
    title = workbook.styles.add_style(b: true, sz: 22, fg_color: "FFFFFF", bg_color: accent, alignment: { vertical: :center })
    header = workbook.styles.add_style(b: true, bg_color: "17211C", fg_color: "FFFFFF", alignment: { vertical: :center })
    label = workbook.styles.add_style(b: true, fg_color: "657269", sz: 9)
    total_label = workbook.styles.add_style(b: true, fg_color: "17211C", bg_color: "E8EFEA", alignment: { horizontal: :right })
    total_money = workbook.styles.add_style(b: true, sz: 15, fg_color: "17211C", bg_color: "E8EFEA", format_code: "#,##0.00", alignment: { horizontal: :right })
    sheet = workbook.add_worksheet(name: excel_text("sheet", "Quotation"))
    sheet.sheet_view.show_grid_lines = false if sheet.sheet_view.respond_to?(:show_grid_lines=)
    sheet.add_row [ excel_text("title", "COMMERCIAL QUOTATION"), nil, nil, nil, nil, nil, nil, nil, nil ], style: title, height: 38
    sheet.merge_cells("A1:I1")
    sheet.add_row [ safe(seller.fetch("name", @revision.company.name)), nil, nil, nil, nil, safe(@revision.quote.quote_no), nil, excel_text("version", "Version"), @revision.number ]
    sheet.add_row [ safe([ seller["address"], seller["email"], seller["phone"] ].compact_blank.join(" · ")), nil, nil, nil, nil, excel_text("issued", "Issued"), @revision.published_at.to_date ]
    sheet.merge_cells("A2:E2"); sheet.merge_cells("A3:E3"); sheet.merge_cells("F2:G2"); sheet.merge_cells("F3:G3")
    sheet.add_row []
    sheet.add_row [ excel_text("buyer", "Buyer"), safe(@revision.snapshot["customer_name"]), nil, nil, nil, excel_text("currency", "Currency"), safe(@revision.currency) ], style: [ label ]
    sheet.merge_cells("B5:E5"); sheet.merge_cells("G5:I5")
    sheet.add_row []
    sheet.add_row [ excel_text("line", "Line"), excel_text("sku", "SKU"), excel_text("description", "Description"), excel_text("specification", "Specification"), excel_text("quantity", "Qty"), excel_text("unit", "Unit"), excel_text("unit_price", "Unit price"), excel_text("discount", "Discount"), excel_text("amount", "Amount") ], style: header, height: 26
    Array(@revision.snapshot["quote_items"]).each_with_index do |item, index|
      quantity = item["quantity"].to_d
      unit_price = item["unit_price"].to_d
      discount = item["discount_amount"].to_d
      specs = Array(item["specifications"]).map { |spec| "#{spec['key'] || spec['name']}: #{spec['value']}" }.join(" | ")
      sheet.add_row [ index + 1, safe(item["sku_snapshot"]), safe(item["product_name"].presence || item["description"]), safe(specs), quantity,
        safe(item["unit_snapshot"]), unit_price, discount, (quantity * unit_price) - discount ],
        style: [ nil, nil, nil, nil, nil, nil, money, money, money ]
    end
    sheet.add_row []
    %w[shipping_amount discount_amount tax_amount].each { |key| sheet.add_row [ nil, nil, nil, nil, nil, nil, excel_text(key, key.humanize), nil, @revision.snapshot[key].to_d ], style: [ nil, nil, nil, nil, nil, nil, total_label, nil, money ] }
    sheet.add_row [ nil, nil, nil, nil, nil, nil, excel_text("total", "Quoted total"), @revision.currency, @revision.total ], style: [ nil, nil, nil, nil, nil, nil, total_label, total_label, total_money ], height: 30
    sheet.add_row []
    sheet.add_row [ excel_text("terms", "COMMERCIAL TERMS") ], style: header
    sheet.merge_cells("A#{sheet.rows.size}:I#{sheet.rows.size}")
    sheet.add_row [ excel_text("incoterm", "Incoterm"), safe(@revision.snapshot["trade_term"]), nil, excel_text("payment", "Payment terms"), safe(@revision.snapshot["payment_term"]), nil, excel_text("delivery", "Delivery"), safe(@revision.snapshot["delivery_notes"]) ]
    sheet.merge_cells("B#{sheet.rows.size}:C#{sheet.rows.size}"); sheet.merge_cells("E#{sheet.rows.size}:F#{sheet.rows.size}"); sheet.merge_cells("H#{sheet.rows.size}:I#{sheet.rows.size}")
    custom_fields = Array(@revision.snapshot["custom_fields"]).select { |field| @revision.snapshot.fetch("custom_field_values", {})[field["key"]].present? }
    if custom_fields.any?
      sheet.add_row []
      sheet.add_row [ excel_text("custom_fields", "ADDITIONAL INFORMATION") ], style: header
      sheet.merge_cells("A#{sheet.rows.size}:I#{sheet.rows.size}")
      custom_fields.each do |field|
        sheet.add_row [ safe(field["label"]), nil, safe(@revision.snapshot.fetch("custom_field_values", {})[field["key"]]) ], style: [ label ]
        sheet.merge_cells("A#{sheet.rows.size}:B#{sheet.rows.size}")
        sheet.merge_cells("C#{sheet.rows.size}:I#{sheet.rows.size}")
      end
    end
    sheet.column_widths 8, 18, 32, 38, 12, 12, 16, 14, 18
    sheet.sheet_view.pane do |pane| pane.top_left_cell = "A8"; pane.state = :frozen; pane.y_split = 7 end
    sheet.auto_filter = "A7:I7"
    sheet.page_margins.set(left: 0.3, right: 0.3, top: 0.5, bottom: 0.5)
    sheet.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0, paper_width: "297mm", paper_height: "210mm")

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

  def design
    @design ||= @revision.snapshot.fetch("document_design", {})
  end

  def seller
    @seller ||= @revision.snapshot.fetch("seller_company", {})
  end

  def excel_text(key, fallback)
    I18n.with_locale(design["excel_locale"].presence || buyer_locale) do
      I18n.t("self_service.buyer_room.excel.#{key}", default: fallback)
    end
  end

  def buyer_locale
    @revision.snapshot["buyer_locale"].presence_in(Quote::BUYER_LOCALES) || @revision.quote.buyer_locale || "en"
  end

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
