class QuoteExporter
  EXCEL_SUPPORTED_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/gif image/bmp].freeze

  def initialize(quote, template: nil)
    @quote = quote
    @company = quote.company
    @customer = quote.customer
    @template = template || @company.quote_template_or_default
    @excel_tempfiles = []
  end

  def to_pdf
    require "prawn"
    require "prawn/table"

    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    configure_pdf_font(pdf)
    render_pdf_header(pdf)
    render_pdf_party_block(pdf)
    render_pdf_items(pdf)
    render_pdf_totals(pdf)
    render_pdf_terms(pdf)
    render_pdf_signature(pdf)
    pdf
  end

  def to_xlsx
    require "axlsx"
    require "tempfile"

    package = Axlsx::Package.new
    workbook = package.workbook
    sheet = workbook.add_worksheet(name: "Quote")
    styles = workbook.styles

    title_style = styles.add_style(sz: 16, b: true)
    section_style = styles.add_style(sz: 12, b: true)
    header_style = styles.add_style(b: true, bg_color: "E9ECEF", border: { style: :thin, color: "CCCCCC" })
    cell_style = styles.add_style(border: { style: :thin, color: "E2E2E2" })
    number_style = styles.add_style(border: { style: :thin, color: "E2E2E2" }, format_code: "#,##0.00")
    total_label_style = styles.add_style(b: true)
    total_value_style = styles.add_style(b: true, format_code: "#,##0.00")

    sheet.add_row [ "QUOTATION" ], style: title_style
    sheet.add_row [ @company.name ]
    sheet.add_row [ "Quote ##{@quote.quote_no}" ]
    sheet.add_row [ "Quote Date", @quote.issued_on&.strftime("%Y-%m-%d") || "-" ]
    sheet.add_row [ "Valid Until", @quote.valid_until&.strftime("%Y-%m-%d") || "-" ] if @template.show_valid_until
    sheet.add_row [ "Currency", @quote.currency ] if @template.show_currency
    sheet.add_row []

    sheet.add_row [ "Seller", @company.name ], style: section_style
    sheet.add_row [ "Address", @company.address ]
    sheet.add_row [ "Phone", @company.phone ]
    sheet.add_row [ "Email", @company.email ]
    sheet.add_row [ "Website", @company.website ]
    sheet.add_row []

    sheet.add_row [ "Buyer", @customer.name ], style: section_style
    sheet.add_row [ "Contact", @customer.contact_name ]
    sheet.add_row [ "Address", @customer.address ]
    sheet.add_row [ "Phone", @customer.phone ]
    sheet.add_row [ "Email", @customer.email ]
    sheet.add_row []

    headers = [ "No." ]
    headers << "Image" if @template.show_product_images
    headers.concat([ "Description", "Qty", "Unit Price", "Line Total" ])
    sheet.add_row headers, style: header_style

    image_col_index = headers.index("Image")
    @quote.quote_items.ordered.each_with_index do |item, idx|
      row_values = [ idx + 1 ]
      row_values << "" if @template.show_product_images
      row_values.concat([ item.description, item.quantity, item.unit_price.to_f, item.amount.to_f ])

      row_styles = Array.new(headers.size, cell_style)
      row_styles[headers.index("Unit Price")] = number_style
      row_styles[headers.index("Line Total")] = number_style
      sheet.add_row row_values, style: row_styles

      add_excel_item_image(sheet, item, image_col_index) if @template.show_product_images
    end

    item_end_row = sheet.rows.size
    line_total_index = headers.index("Line Total")
    label_index = line_total_index - 1

    sheet.add_row []
    sheet.add_row summary_row_data("Subtotal", @quote.subtotal.to_f, headers.size, label_index, line_total_index),
                  style: summary_row_styles(headers.size, label_index, line_total_index, total_label_style, total_value_style)
    sheet.add_row summary_row_data("Tax / VAT", @quote.tax_amount.to_f, headers.size, label_index, line_total_index),
                  style: summary_row_styles(headers.size, label_index, line_total_index, total_label_style, total_value_style)
    sheet.add_row summary_row_data("Shipping", @quote.shipping_amount.to_f, headers.size, label_index, line_total_index),
                  style: summary_row_styles(headers.size, label_index, line_total_index, total_label_style, total_value_style)
    sheet.add_row summary_row_data("Discount", @quote.discount_amount.to_f, headers.size, label_index, line_total_index),
                  style: summary_row_styles(headers.size, label_index, line_total_index, total_label_style, total_value_style)

    sheet.add_row summary_row_data("Grand Total", @quote.grand_total.to_f, headers.size, label_index, line_total_index),
                  style: summary_row_styles(headers.size, label_index, line_total_index, total_label_style, total_value_style)

    if @template.show_terms_section
      sheet.add_row []
      sheet.add_row [ "Terms & Conditions" ], style: section_style
      sheet.add_row [ "Payment Terms", @quote.payment_term ]
      sheet.add_row [ "Terms", @quote.terms_text ]
      sheet.add_row [ "Legal Disclaimer", @quote.legal_disclaimer ]
      sheet.add_row [ "Delivery Notes", @quote.delivery_notes ]
    end

    if @template.show_notes && @quote.notes.present?
      sheet.add_row []
      sheet.add_row [ "Notes", @quote.notes ]
    end

    if @template.show_signature_block
      sheet.add_row []
      sheet.add_row [ "Customer acceptance:" ]
      sheet.add_row [ "____________________" ]
      sheet.add_row [ "Date: ____________" ]
    end

    widths = []
    headers.each do |header|
      widths << case header
      when "No." then 6
      when "Image" then 14
      when "Description" then 36
      when "Qty" then 8
      when "Unit Price" then 14
      when "Line Total" then 14
      else 20
      end
    end
    sheet.column_widths(*widths)
    package
  end

  private

  def render_pdf_header(pdf)
    if @template.show_logo && @company.logo.attached?
      begin
        logo_path = ActiveStorage::Blob.service.path_for(@company.logo.blob.key)
        pdf.image logo_path, fit: [ 160, 70 ]
      rescue StandardError
        pdf.text @company.name, size: 16, style: :bold
      end
    else
      pdf.text @company.name, size: 16, style: :bold
    end
    pdf.move_down 8
    pdf.text "QUOTATION", size: 18, style: :bold
    pdf.text "Quote ##{@quote.quote_no}"
    pdf.text "Quote Date: #{@quote.issued_on&.strftime('%Y-%m-%d') || '-'}"
    pdf.text "Valid Until: #{@quote.valid_until&.strftime('%Y-%m-%d') || '-'}" if @template.show_valid_until
    pdf.text "Currency: #{@quote.currency}" if @template.show_currency
    pdf.move_down 10
  end

  def render_pdf_party_block(pdf)
    seller_lines = [
      "Seller: #{@company.name}",
      @company.address,
      @company.phone,
      @company.email,
      @company.website
    ].compact_blank

    buyer_lines = [
      "Buyer: #{@customer.name}",
      "Contact: #{@customer.contact_name}",
      @customer.address,
      @customer.phone,
      @customer.email
    ].compact_blank

    rows = [ [ seller_lines.join("\n"), buyer_lines.join("\n") ] ]
    pdf.table(rows, width: pdf.bounds.width, cell_style: { borders: [], padding: [ 0, 6, 10, 0 ] })
  end

  def render_pdf_items(pdf)
    rows = [ pdf_item_headers ]
    @quote.quote_items.ordered.each_with_index do |item, idx|
      row = [ idx + 1 ]
      row << pdf_image_cell(item) if @template.show_product_images
      row << item.description
      row << item.quantity
      row << decimal_text(item.unit_price)
      row << decimal_text(item.amount)
      rows << row
    end

    pdf.table(rows, header: true, width: pdf.bounds.width) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = "EFEFEF"
      table.columns(-2..-1).align = :right
      if @template.show_product_images
        image_index = pdf_item_headers.index("Image")
        table.columns(image_index).width = 60
      end
    end
  end

  def render_pdf_totals(pdf)
    pdf.move_down 10
    rows = [
      [ "Subtotal", decimal_text(@quote.subtotal) ],
      [ "Tax / VAT", decimal_text(@quote.tax_amount) ],
      [ "Shipping", decimal_text(@quote.shipping_amount) ],
      [ "Discount", decimal_text(@quote.discount_amount) ],
      [ "Grand Total", decimal_text(@quote.grand_total) ]
    ]
    rows.each_with_index do |row, idx|
      style = idx == rows.size - 1 ? :bold : :normal
      label = row[0]
      amount = "#{row[1]}#{@template.show_currency ? " #{@quote.currency}" : ""}"
      pdf.text "#{label}: #{amount}", style: style, align: :right
    end
  end

  def render_pdf_terms(pdf)
    return unless @template.show_terms_section

    pdf.move_down 12
    pdf.text "Terms & Conditions", style: :bold
    pdf.text "Payment Terms: #{@quote.payment_term.presence || '-'}"
    pdf.text "Terms: #{@quote.terms_text.presence || '-'}"
    pdf.text "Legal Disclaimer: #{@quote.legal_disclaimer.presence || '-'}"
    pdf.text "Delivery Notes: #{@quote.delivery_notes.presence || '-'}"
    if @template.show_notes && @quote.notes.present?
      pdf.move_down 6
      pdf.text "Notes: #{@quote.notes}"
    end
  end

  def render_pdf_signature(pdf)
    return unless @template.show_signature_block

    pdf.move_down 16
    pdf.text "Customer acceptance:"
    pdf.text "________________________"
    pdf.text "Date: _________________"
  end

  def decimal_text(value)
    format("%.2f", value.to_d)
  end

  def pdf_image_cell(item)
    return "-" unless item.product&.image&.attached?

    path = ActiveStorage::Blob.service.path_for(item.product.image.blob.key)
    { image: path, fit: [ 44, 44 ], position: :center, vposition: :center }
  rescue StandardError
    "Image"
  end

  def pdf_item_headers
    headers = [ "No." ]
    headers << "Image" if @template.show_product_images
    headers.concat([ "Description", "Qty", "Unit Price", "Line Total" ])
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

  def configure_pdf_font(pdf)
    candidates = [
      "C:/Windows/Fonts/simhei.ttf",
      "C:/Windows/Fonts/simsunb.ttf",
      "C:/Windows/Fonts/Deng.ttf",
      Rails.root.join("app/assets/fonts/NotoSansSC-Regular.ttf").to_s
    ]

    candidates.each do |path|
      next unless File.exist?(path)

      begin
        pdf.font_families.update("quote_unicode" => {
          normal: path,
          bold: path,
          italic: path,
          bold_italic: path
        })
        pdf.font("quote_unicode")
        return
      rescue StandardError
        next
      end
    end
  end

  def add_excel_item_image(sheet, item, image_col_index)
    return if image_col_index.nil?
    return unless item.product&.image&.attached?

    image_path = excel_image_path_for(item)
    return if image_path.blank?

    row_index = sheet.rows.size - 1
    sheet.rows[row_index].height = 44

    sheet.add_image(image_src: image_path) do |image|
      image.start_at(image_col_index, row_index)
      image.width = 40
      image.height = 40
    end
  rescue StandardError
    # Keep export robust even if image embedding fails for one row.
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

  def cleanup_tempfiles!
    @excel_tempfiles.each do |file|
      file.close!
    rescue StandardError
      next
    end
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

  public :cleanup_tempfiles!
end
