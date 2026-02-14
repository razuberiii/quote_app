class QuoteExporter
  EXCEL_SUPPORTED_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/gif image/bmp].freeze
  FONT_MAP = {
    "Noto Sans" => [
      "C:/Windows/Fonts/NotoSans-Regular.ttf",
      "C:/Windows/Fonts/simhei.ttf",
      Rails.root.join("app/assets/fonts/NotoSansSC-Regular.ttf").to_s
    ],
    "Inter" => [
      "C:/Windows/Fonts/Inter-Regular.ttf",
      "C:/Windows/Fonts/segoeui.ttf"
    ],
    "Segoe UI" => [ "C:/Windows/Fonts/segoeui.ttf" ],
    "Arial" => [ "C:/Windows/Fonts/arial.ttf" ],
    "Helvetica" => []
  }.freeze

  def initialize(quote, template: nil, document_kind: "quote")
    @quote = quote
    @company = quote.company
    @customer = quote.customer
    @template = template || quote.template || @company.quote_template_or_default
    @document_kind = @template.normalize_document_kind(document_kind)
    @excel_tempfiles = []
    @excel_row_index_map = {}
  end

  def to_pdf
    require "prawn"
    require "prawn/table"

    pdf = Prawn::Document.new(page_size: "A4", margin: [ 56, 42, 56, 42 ])
    configure_pdf_font(pdf)

    render_pdf_header(pdf)
    render_pdf_parties(pdf)
    render_pdf_items(pdf)
    render_pdf_totals(pdf)
    render_pdf_terms(pdf)
    render_pdf_footer(pdf)
    render_pdf_signature(pdf)

    pdf
  end

  def to_xlsx
    require "axlsx"
    require "tempfile"

    config = excel_template_config
    package = Axlsx::Package.new
    workbook = package.workbook
    sheet = workbook.add_worksheet(name: config.fetch("sheet_name", xlsx_sheet_name))
    styles = build_excel_styles(workbook)

    apply_excel_sheet_options(sheet)
    render_excel_header(sheet, styles, config)
    render_excel_parties(sheet, styles)
    header_ctx = render_excel_items(sheet, styles)
    render_excel_totals(sheet, styles, header_ctx)
    render_excel_sections(sheet, styles)
    apply_excel_post_layout(sheet, header_ctx, config)

    package
  end

  def cleanup_tempfiles!
    @excel_tempfiles.each do |file|
      file.close!
    rescue StandardError
      next
    end
  end

  private

  def render_pdf_header(pdf)
    width = pdf_content_width(pdf)

    title = @template.resolved_document_title(@document_kind)
    pdf.character_spacing(1) do
      pdf.fill_color pdf_color
      pdf.text title, size: 24, style: :bold
    end
    pdf.fill_color "000000"

    pdf.move_down 4
    pdf.stroke_color pdf_color
    pdf.line_width = 2
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.line_width = 1
    pdf.move_down 8

    seller_title = @company.name.to_s
    left_lines = [
      seller_title,
      @company.address,
      @company.phone,
      @company.email,
      @company.website
    ].compact_blank.join("\n")

    right_lines = [
      "#{@template.resolved_document_number_label(@document_kind)} #{@quote.quote_no}",
      "#{document_date_label}: #{@quote.issued_on&.strftime('%Y-%m-%d') || '-'}",
      (@template.show_valid_until ? "Valid Until: #{@quote.valid_until&.strftime('%Y-%m-%d') || '-'}" : nil),
      (@template.show_currency ? "Currency: #{@quote.currency}" : nil)
    ].compact.join("\n")

    pdf.table([ [ left_lines, right_lines ] ], width: width, cell_style: { borders: [], padding: [ 2, 0, 2, 0 ] }) do |t|
      t.columns(0).width = width * 0.58
      t.columns(1).width = width * 0.42
      t.columns(1).align = :right
    end

    pdf.move_down 14
  end

  def render_pdf_parties(pdf)
    width = pdf_content_width(pdf)
    accent = pdf_color

    seller_lines = [
      "SELLER",
      @company.name,
      @company.address,
      @company.phone,
      @company.email,
      @company.website
    ].compact_blank.join("\n")

    buyer_lines = [
      "BUYER",
      @customer.name,
      "Contact: #{@customer.contact_name}",
      @customer.address,
      @customer.phone,
      @customer.email
    ].compact_blank.join("\n")

    pdf.table([ [ seller_lines, buyer_lines ] ], width: width) do |t|
      t.cells.borders = []
      t.cells.background_color = "F8F9FA"
      t.cells.padding = 12
      t.cells.border_left_width = 3
      t.cells.border_left_color = accent
      t.row(0).font_style = :normal
    end

    pdf.move_down 12
  end

  def render_pdf_items(pdf)
    width = pdf_content_width(pdf)
    rows = [ pdf_item_headers ]

    @quote.quote_items.ordered.each_with_index do |item, idx|
      row = [ idx + 1 ]
      row << pdf_image_cell(item) if @template.show_images?
      row << item.description
      row << item.quantity
      row << decimal_text(item.unit_price)
      row << decimal_text(item.amount)
      rows << row
    end

    qty_col = pdf_item_headers.index("Qty")
    unit_col = pdf_item_headers.index("Unit Price")
    total_col = pdf_item_headers.index("Line Total")

    pdf.table(rows, header: true, width: width) do |t|
      t.cells.borders = []
      t.cells.padding = [ 10, 6, 10, 6 ]

      t.row(0).font_style = :bold
      t.row(0).borders = [ :bottom ]
      t.row(0).border_bottom_width = 1
      t.row(0).border_bottom_color = "DDDDDD"

      t.columns(qty_col).align = :right
      t.columns(unit_col).align = :right
      t.columns(total_col).align = :right

      if @template.show_images?
        image_col = pdf_item_headers.index("Image")
        t.columns(image_col).width = 60
      end
    end

    pdf.move_down 14
  end

  def render_pdf_totals(pdf)
    totals_rows = []
    totals_rows << [ "Subtotal", total_value_text(@quote.subtotal) ]
    totals_rows << [ "Tax / VAT", total_value_text(@quote.tax_amount) ] if @template.show_tax
    totals_rows << [ "Shipping", total_value_text(@quote.shipping_amount) ] if @template.show_shipping
    totals_rows << [ "Discount", total_value_text(@quote.discount_amount) ]
    totals_rows << [ "Grand Total", total_value_text(@quote.grand_total) ]

    width = [ pdf_content_width(pdf) * 0.5, 300 ].min

    pdf.table(totals_rows, width: width, position: :right) do |t|
      t.cells.borders = []
      t.cells.padding = [ 8, 10, 8, 10 ]
      t.cells.background_color = "F8F9FA"
      t.columns(1).align = :right
      t.columns(1).font_style = :bold

      t.row(-1).background_color = pdf_color
      t.row(-1).text_color = "FFFFFF"
      t.row(-1).font_style = :bold
      t.row(-1).size = 18
    end

    pdf.move_down 12
  end

  def render_pdf_terms(pdf)
    return unless @template.show_terms_section

    lines = []
    lines << "Payment Terms: #{@quote.payment_term.presence || '-'}" if @template.show_payment_term
    lines << "Terms: #{@quote.terms_text.presence || '-'}"
    lines << "Legal Disclaimer: #{@quote.legal_disclaimer.presence || '-'}"
    lines << "Delivery Notes: #{@quote.delivery_notes.presence || '-'}"
    lines << "Notes: #{@quote.notes}" if @template.show_notes && @quote.notes.present?
    return if lines.empty?

    pdf.text "Terms & Conditions", style: :bold, size: 11
    pdf.move_down 4
    lines.each { |line| pdf.text line, size: 10 }
    pdf.move_down 10
  end

  def render_pdf_footer(pdf)
    footer_note = @template.resolved_footer_note(@document_kind)
    return if footer_note.blank?

    pdf.text "Footer", style: :bold, size: 11
    pdf.move_down 3
    pdf.text footer_note, size: 10
    pdf.move_down 8
  end

  def render_pdf_signature(pdf)
    return unless @template.show_signature_block

    pdf.move_down 8
    pdf.text "Customer acceptance:"
    pdf.text "________________________"
    pdf.text "Date: _________________"
  end

  def render_excel_header(sheet, styles, config)
    title = @template.resolved_document_title(@document_kind)
    sheet.add_row [ title, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:title]), height: 30
    sheet.merge_cells(config.fetch("title_merge", "A1:F1"))

    sheet.add_row [ @company.name, nil, nil, "#{@template.resolved_document_number_label(@document_kind)} #{@quote.quote_no}", nil, nil ],
                  style: [ styles[:meta], styles[:meta], styles[:meta], styles[:meta_right], styles[:meta_right], styles[:meta_right] ],
                  height: 22
    sheet.merge_cells("A2:C2")
    sheet.merge_cells(config.fetch("number_merge", "D2:F2"))

    sheet.add_row [ document_date_label, @quote.issued_on&.strftime("%Y-%m-%d") || "-", nil, nil, nil, nil ],
                  style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ],
                  height: 20
    sheet.merge_cells("B3:C3")
    sheet.merge_cells("D3:F3")
    if @template.show_valid_until
      sheet.add_row [ "Valid Until", @quote.valid_until&.strftime("%Y-%m-%d") || "-", nil, nil, nil, nil ],
                    style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ],
                    height: 20
      sheet.merge_cells("B4:C4")
      sheet.merge_cells("D4:F4")
    end
    if @template.show_currency
      row_index = sheet.rows.size + 1
      sheet.add_row [ "Currency", @quote.currency, nil, nil, nil, nil ],
                    style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ],
                    height: 20
      sheet.merge_cells("B#{row_index}:C#{row_index}")
      sheet.merge_cells("D#{row_index}:F#{row_index}")
    end

    divider_row = sheet.rows.size + 1
    sheet.add_row [ nil, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:title_underline]), height: 8
    sheet.merge_cells("A#{divider_row}:F#{divider_row}")
    sheet.add_row []
  end

  def render_excel_parties(sheet, styles)
    start_row = sheet.rows.size + 1
    sheet.add_row [ "Seller", nil, "Buyer", nil, "Quote Info", nil ],
                  style: [ styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block] ],
                  height: 22
    sheet.merge_cells("A#{start_row}:B#{start_row}")
    sheet.merge_cells("C#{start_row}:D#{start_row}")
    sheet.merge_cells("E#{start_row}:F#{start_row}")

    detail_rows = [
      [ @company.name, @customer.name, "#{document_date_label}: #{@quote.issued_on&.strftime('%Y-%m-%d') || '-'}" ],
      [ @company.address.presence || "-", @customer.address.presence || "-", (@template.show_valid_until ? "Valid Until: #{@quote.valid_until&.strftime('%Y-%m-%d') || '-'}" : "-") ],
      [ @company.phone.presence || "-", @customer.phone.presence || "-", (@template.show_currency ? "Currency: #{@quote.currency}" : "-") ],
      [ @company.email.presence || "-", @customer.email.presence || "-", (@template.show_payment_term ? "Payment: #{@quote.payment_term.presence || '-'}" : "-") ],
      [ @company.website.presence || "-", "Contact: #{@customer.contact_name.presence || '-'}", "" ]
    ]

    detail_rows.each_with_index do |(seller_text, buyer_text, info_text), idx|
      row_no = start_row + idx + 1
      sheet.add_row [ seller_text, nil, buyer_text, nil, info_text, nil ],
                    style: [ styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell] ],
                    height: 20
      sheet.merge_cells("A#{row_no}:B#{row_no}")
      sheet.merge_cells("C#{row_no}:D#{row_no}")
      sheet.merge_cells("E#{row_no}:F#{row_no}")
    end

    sheet.add_row []
  end

  def render_excel_items(sheet, styles)
    headers = [ "No.", "Image", "Description", "Qty", "Unit Price", "Line Total" ]
    sheet.add_row headers, style: Array.new(6, styles[:header]), height: 24
    header_row_index = sheet.rows.size - 1

    image_col_index = 1
    qty_col = 3
    unit_col = 4
    total_col = 5

    @quote.quote_items.ordered.each_with_index do |item, idx|
      row = [ idx + 1, "", item.description, item.quantity, item.unit_price.to_f, item.amount.to_f ]
      row_styles = Array.new(6, styles[:cell])
      row_styles[qty_col] = styles[:number]
      row_styles[unit_col] = styles[:currency]
      row_styles[total_col] = styles[:currency]

      sheet.add_row row, style: row_styles, height: 24
      row_index = sheet.rows.size - 1
      @excel_row_index_map[item.id] = row_index
      add_excel_item_image(sheet, item, image_col_index) if @template.show_images?
    end

    sheet.add_row []

    {
      header_row_index: header_row_index,
      width: 6,
      label_col: 3,
      value_col: 5
    }
  end

  def render_excel_totals(sheet, styles, ctx)
    separator_row = sheet.rows.size + 1
    sheet.add_row [ nil, nil, nil, nil, nil, nil ],
                  style: [ nil, nil, nil, styles[:totals_separator], styles[:totals_separator], styles[:totals_separator] ],
                  height: 8
    sheet.merge_cells("A#{separator_row}:C#{separator_row}")
    sheet.merge_cells("D#{separator_row}:E#{separator_row}")

    totals_start = sheet.rows.size + 1
    add_excel_total_row(sheet, "Subtotal", @quote.subtotal.to_f, ctx, styles)
    add_excel_total_row(sheet, "Tax / VAT", @quote.tax_amount.to_f, ctx, styles) if @template.show_tax
    add_excel_total_row(sheet, "Shipping", @quote.shipping_amount.to_f, ctx, styles) if @template.show_shipping
    add_excel_total_row(sheet, "Discount", @quote.discount_amount.to_f, ctx, styles)

    row = summary_row_data("Grand Total", @quote.grand_total.to_f, ctx[:width], ctx[:label_col], ctx[:value_col])
    style = summary_row_styles(ctx[:width], ctx[:label_col], ctx[:value_col], styles[:grand_total_label], styles[:grand_total])
    sheet.add_row row, style: style, height: 30

    totals_end = sheet.rows.size
    (totals_start..totals_end).each do |row_no|
      sheet.merge_cells("A#{row_no}:C#{row_no}")
      sheet.merge_cells("D#{row_no}:E#{row_no}")
    end
  end

  def render_excel_sections(sheet, styles)
    if @template.show_terms_section
      sheet.add_row []
      sheet.add_row [ "Terms & Conditions" ], style: styles[:section]
      sheet.merge_cells("A#{sheet.rows.size}:F#{sheet.rows.size}")
      sheet.add_row [ "Payment Terms", @quote.payment_term, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ] if @template.show_payment_term
      sheet.add_row [ "Terms", @quote.terms_text, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ]
      sheet.add_row [ "Legal Disclaimer", @quote.legal_disclaimer, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ]
      sheet.add_row [ "Delivery Notes", @quote.delivery_notes, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ]
    end

    if @template.show_notes && @quote.notes.present?
      sheet.add_row []
      row = sheet.rows.size + 1
      sheet.add_row [ "Notes", @quote.notes, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ]
      sheet.merge_cells("B#{row}:F#{row}")
    end

    footer_note = @template.resolved_footer_note(@document_kind)
    if footer_note.present?
      sheet.add_row []
      row = sheet.rows.size + 1
      sheet.add_row [ "Footer", footer_note, nil, nil, nil, nil ], style: [ styles[:meta_label], styles[:meta], styles[:meta], styles[:meta], styles[:meta], styles[:meta] ]
      sheet.merge_cells("B#{row}:F#{row}")
    end
  end

  def apply_excel_sheet_options(sheet)
    sheet.sheet_view.show_grid_lines = false if sheet.sheet_view.respond_to?(:show_grid_lines=)
  rescue StandardError
    nil
  end

  def apply_excel_post_layout(sheet, ctx, config)
    widths = config["column_widths"] || [ 6, 12, 34, 10, 14, 16 ]
    sheet.column_widths(*widths)

    freeze = config["freeze_pane"]
    return unless freeze

    sheet.sheet_view.pane do |pane|
      pane.top_left_cell = freeze.fetch("top_left_cell", "A1")
      pane.state = :frozen
      pane.y_split = freeze.fetch("y_split", ctx[:header_row_index] + 1)
    end
  end

  def build_excel_styles(workbook)
    styles = workbook.styles
    font = @template.font_family
    accent = excel_color
    dark_header = darken_color(accent, 0.18)
    border = "CBD5E1"

    {
      title: styles.add_style(sz: 20, b: true, fg_color: accent, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      title_underline: styles.add_style(border: { style: :thin, color: accent, edges: [ :bottom ] }, font_name: font),
      section: styles.add_style(sz: 12, b: true, fg_color: accent, font_name: font),
      section_block: styles.add_style(sz: 11, b: true, fg_color: accent, bg_color: "F8FAFC", border: { style: :thin, color: border, edges: [ :bottom ] }, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      block_cell: styles.add_style(alignment: { vertical: :top, wrap_text: true }, font_name: font),
      meta_label: styles.add_style(b: true, fg_color: "334155", font_name: font),
      meta: styles.add_style(font_name: font),
      meta_right: styles.add_style(alignment: { horizontal: :right }, font_name: font),
      header: styles.add_style(b: true, bg_color: dark_header, fg_color: "FFFFFF", border: { style: :thin, color: border, edges: [ :bottom ] }, alignment: { horizontal: :center, vertical: :center }, font_name: font),
      cell: styles.add_style(border: { style: :thin, color: border, edges: [ :bottom ] }, alignment: { vertical: :center }, font_name: font),
      number: styles.add_style(border: { style: :thin, color: border, edges: [ :bottom ] }, format_code: "0", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      currency: styles.add_style(border: { style: :thin, color: border, edges: [ :bottom ] }, format_code: "#,##0.00", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      totals_separator: styles.add_style(border: { style: :thin, color: border, edges: [ :top ] }, font_name: font),
      total_label: styles.add_style(b: true, alignment: { horizontal: :right, vertical: :center }, bg_color: "F8FAFC", font_name: font),
      total_value: styles.add_style(b: true, format_code: "#,##0.00", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      grand_total_label: styles.add_style(b: true, sz: 12, bg_color: accent, fg_color: "FFFFFF", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      grand_total: styles.add_style(b: true, sz: 14, bg_color: accent, fg_color: "FFFFFF", format_code: "#,##0.00", alignment: { horizontal: :right, vertical: :center }, font_name: font)
    }
  end

  def add_excel_total_row(sheet, label, value, ctx, styles)
    row = summary_row_data(label, value, ctx[:width], ctx[:label_col], ctx[:value_col])
    row_style = summary_row_styles(ctx[:width], ctx[:label_col], ctx[:value_col], styles[:total_label], styles[:total_value])
    sheet.add_row row, style: row_style
  end

  def summary_row_data(label, value, width, label_index, value_index)
    row = Array.new(width)
    row[label_index] = label
    row[value_index] = value
    row
  end

  def summary_row_styles(width, label_index, value_index, label_style, value_style)
    styles = Array.new(width)
    styles[label_index] = label_style
    styles[value_index] = value_style
    styles
  end

  def add_excel_item_image(sheet, item, image_col_index)
    return if image_col_index.nil?
    return unless @template.show_images?
    return unless item.product&.image&.attached?

    image_path = excel_image_path_for(item)
    return if image_path.blank?

    row_index = @excel_row_index_map[item.id] || sheet.rows.size - 1
    sheet.rows[row_index].height = 40

    sheet.add_image(image_src: image_path) do |image|
      image.start_at(image_col_index, row_index)
      image.width = 34
      image.height = 34
    end
  rescue StandardError
    nil
  end

  def excel_image_path_for(item)
    blob = item.product.image.blob
    return nil unless EXCEL_SUPPORTED_IMAGE_TYPES.include?(blob.content_type.to_s.downcase)

    ext = File.extname(blob.filename.to_s)
    ext = default_extension_for(blob.content_type) if ext.blank?
    tempfile = Tempfile.new([ "quote_item_image", ext ])
    tempfile.binmode
    tempfile.write(blob.download)
    tempfile.flush
    @excel_tempfiles << tempfile
    tempfile.path
  rescue StandardError
    nil
  end

  def default_extension_for(content_type)
    case content_type.to_s.downcase
    when "image/png" then ".png"
    when "image/jpeg", "image/jpg" then ".jpg"
    when "image/gif" then ".gif"
    when "image/bmp" then ".bmp"
    else ".img"
    end
  end

  def pdf_item_headers
    headers = [ "No." ]
    headers << "Image" if @template.show_images?
    headers.concat([ "Description", "Qty", "Unit Price", "Line Total" ])
  end

  def pdf_image_cell(item)
    return "-" unless @template.show_images?
    return "-" unless item.product&.image&.attached?

    path = ActiveStorage::Blob.service.path_for(item.product.image.blob.key)
    { image: path, fit: [ 38, 38 ], position: :center, vposition: :center }
  rescue StandardError
    "Image"
  end

  def configure_pdf_font(pdf)
    candidates = FONT_MAP.fetch(@template.font_family, []) + FONT_MAP["Noto Sans"]

    candidates.each do |path|
      next unless File.exist?(path)

      begin
        pdf.font_families.update("quote_custom" => {
          normal: path,
          bold: path,
          italic: path,
          bold_italic: path
        })
        pdf.font("quote_custom")
        return
      rescue StandardError
        next
      end
    end
  end

  def excel_template_config
    require "yaml"

    path = Rails.root.join("app/templates/excel/#{@template.layout_type}.yml")
    YAML.load_file(path)
  rescue StandardError
    {
      "sheet_name" => xlsx_sheet_name,
      "column_widths" => [ 6, 14, 36, 8, 14, 16 ],
      "title_merge" => "A1:F1"
    }
  end

  def xlsx_sheet_name
    @document_kind == "pi" ? "PI" : "Quote"
  end

  def document_date_label
    @document_kind == "pi" ? "PI Date" : "Quote Date"
  end

  def total_value_text(value)
    suffix = @template.show_currency ? " #{@quote.currency}" : ""
    "#{decimal_text(value)}#{suffix}"
  end

  def decimal_text(value)
    format("%.2f", value.to_d)
  end

  def pdf_content_width(pdf)
    [ pdf.bounds.width, 820 ].min
  end

  def pdf_color
    sanitize_hex_color(@template.accent_color)
  end

  def excel_color
    sanitize_hex_color(@template.accent_color)
  end

  def sanitize_hex_color(value)
    hex = value.to_s.delete_prefix("#")
    return "1F4E79" unless hex.match?(/\A(?:\h{3}|\h{6})\z/)

    hex.length == 3 ? hex.chars.map { |c| c * 2 }.join.upcase : hex.upcase
  end

  def darken_color(hex, amount)
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    rr = (r * (1 - amount)).round
    gg = (g * (1 - amount)).round
    bb = (b * (1 - amount)).round
    format("%02X%02X%02X", rr, gg, bb)
  end
end
