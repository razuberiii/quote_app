class QuoteExporter
  require "stringio"
  EXCEL_SUPPORTED_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/gif image/bmp].freeze
  FONT_MAP = {
    "Noto Sans" => [
      "C:/Windows/Fonts/NotoSans-Regular.ttf",
      "C:/Windows/Fonts/simhei.ttf",
      Rails.root.join("app/assets/fonts/NotoSansSC-Regular.ttf").to_s,
      Rails.root.join("vendor/fonts/NotoSansSC-Regular.ttf").to_s
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
    render_pdf_watermark(pdf)

    render_pdf_header(pdf)
    render_pdf_parties(pdf)
    render_pdf_items(pdf)
    render_pdf_totals(pdf)
    render_pdf_terms(pdf)
    render_pdf_company_credentials(pdf)
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

  def render_pdf_watermark(pdf)
    return unless @template.show_watermark

    image_io = template_watermark_image_io
    watermark_text = pdf_watermark_text
    return if image_io.blank? && watermark_text.blank?

    alpha = watermark_alpha
    pdf.repeat(:all, dynamic: true) do
      pdf.canvas do
        if image_io.present?
          image_io.rewind if image_io.respond_to?(:rewind)
          width = pdf.bounds.width * 0.48
          height = pdf.bounds.height * 0.38
          x = (pdf.bounds.width - width) / 2.0
          y = (pdf.bounds.height + height) / 2.0
          pdf.transparent(alpha) do
            pdf.image(image_io, at: [ x, y ], fit: [ width, height ])
          end
        elsif watermark_text.present?
          pdf.transparent(alpha) do
            pdf.fill_color "0F172A"
            center_x = pdf.bounds.width / 2.0
            center_y = pdf.bounds.height / 2.0
            pdf.rotate(-18, origin: [ center_x, center_y ]) do
              pdf.text_box(
                pdf_text(watermark_text),
                at: [ 0, center_y + 36 ],
                width: pdf.bounds.width,
                height: 84,
                align: :center,
                valign: :center,
                size: 46,
                style: :bold
              )
            end
            pdf.fill_color "000000"
          end
        end
      end
    end
  rescue StandardError
    nil
  end

  def render_pdf_header(pdf)
    width = pdf_content_width(pdf)

    title = @template.resolved_document_title(@document_kind)
    pdf.character_spacing(1) do
      pdf.fill_color pdf_color
      pdf.text pdf_text(title), size: 24, style: :bold
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
    ].compact_blank.map { |line| pdf_text(line) }.join("\n")

    right_lines = [
      "#{@template.resolved_document_number_label(@document_kind)} #{@quote.quote_no}",
      "#{document_date_label}: #{@quote.issued_on&.strftime('%Y-%m-%d') || '-'}",
      (@template.show_valid_until && @quote.valid_until.present? ? "#{doc_t('labels.valid_until')}: #{@quote.valid_until.strftime('%Y-%m-%d')}" : nil),
      (@template.show_currency ? "#{doc_t('labels.currency')}: #{@quote.currency}" : nil),
      (@quote.trade_term.present? ? "#{doc_t('labels.trade_terms')}: #{@quote.trade_term}" : nil)
    ].compact.map { |line| pdf_text(line) }.join("\n")

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
    sales_owner_line = sales_owner_display_name.present? ? "#{doc_t('labels.sales_owner')}: #{sales_owner_display_name}" : nil

    seller_lines = [
      doc_t("labels.seller").upcase,
      @company.name,
      sales_owner_line,
      @company.address,
      @company.phone,
      @company.email,
      @company.website
    ].compact_blank.map { |line| pdf_text(line) }.join("\n")

    buyer_lines = [
      doc_t("labels.buyer").upcase,
      @customer.name,
      "#{doc_t('labels.contact')}: #{@customer.contact_name}",
      @customer.address,
      @customer.phone,
      @customer.email
    ].compact_blank.map { |line| pdf_text(line) }.join("\n")

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
      row << pdf_text(pdf_item_description_text(item))
      row << item.quantity
      row << money_text(item.unit_price)
      row << money_text(item.line_total)
      rows << row
    end

    qty_col = pdf_item_headers.index(@template.resolved_table_label("qty"))
    unit_col = pdf_item_headers.index(@template.resolved_table_label("unit_price"))
    total_col = pdf_item_headers.index(@template.resolved_table_label("line_total"))

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
      t.columns(qty_col).valign = :top
      t.columns(unit_col).valign = :top
      t.columns(total_col).valign = :top

      if @template.show_images?
        image_col = pdf_item_headers.index(doc_t("labels.image"))
        no_col = 0
        desc_col = pdf_item_headers.index(@template.resolved_table_label("description"))

        t.columns(no_col).width = 26
        t.columns(image_col).width = 54
        t.columns(qty_col).width = 42
        t.columns(unit_col).width = 74
        t.columns(total_col).width = 84
        t.columns(desc_col).width = width - (26 + 54 + 42 + 74 + 84)
      else
        no_col = 0
        desc_col = pdf_item_headers.index(@template.resolved_table_label("description"))

        t.columns(no_col).width = 26
        t.columns(qty_col).width = 42
        t.columns(unit_col).width = 74
        t.columns(total_col).width = 84
        t.columns(desc_col).width = width - (26 + 42 + 74 + 84)
      end

      t.rows(1..-1).columns(unit_col).style(size: 11, font_style: :normal)
      t.rows(1..-1).columns(total_col).style(size: 11, font_style: :normal)
    end

    pdf.move_down 14
  end

  def render_pdf_totals(pdf)
    totals_rows = []
    totals_rows << [ doc_t("labels.subtotal"), total_value_text(@quote.subtotal) ]
    totals_rows << [ doc_t("labels.tax_vat"), total_value_text(@quote.tax_amount) ] if @template.show_tax
    totals_rows << [ doc_t("labels.shipping"), total_value_text(@quote.shipping_amount) ] if @template.show_shipping
    totals_rows << [ doc_t("labels.discount"), total_value_text(@quote.discount_amount) ]
    totals_rows << [ doc_t("labels.grand_total"), total_value_text(@quote.grand_total) ]

    width = [ pdf_content_width(pdf) * 0.43, 260 ].min

    pdf.table(totals_rows, width: width, position: :right) do |t|
      t.cells.borders = []
      t.cells.padding = [ 6, 6, 6, 6 ]
      t.cells.background_color = "FFFFFF"
      t.cells.text_color = "475569"
      t.columns(1).align = :right
      t.columns(1).font_style = :bold
      t.columns(1).size = 11

      t.row(-1).background_color = "FFFFFF"
      t.row(-1).borders = [ :top ]
      t.row(-1).border_top_width = 1
      t.row(-1).border_top_color = "CBD5E1"
      t.row(-1).text_color = "1F3650"
      t.row(-1).font_style = :bold
      t.row(-1).size = 15
    end

    pdf.fill_color "000000"

    pdf.move_down 12
  end

  def render_pdf_terms(pdf)
    return unless @template.show_terms_section

    lines = []
    lines << "#{doc_t('labels.payment_terms')}: #{@quote.payment_term}" if @template.show_payment_term && @quote.payment_term.present?
    lines << "#{doc_t('labels.trade_terms')}: #{@quote.trade_term}" if @quote.trade_term.present?
    lines << "#{doc_t('labels.terms')}: #{@quote.terms_text}" if @quote.terms_text.present?
    lines << "#{doc_t('labels.legal_disclaimer')}: #{@quote.legal_disclaimer}" if @quote.legal_disclaimer.present?
    lines << "#{doc_t('labels.delivery_notes')}: #{@quote.delivery_notes}" if @quote.delivery_notes.present?
    lines << "#{doc_t('labels.notes')}: #{@quote.notes}" if @template.show_notes && @quote.notes.present?
    return if lines.empty?

    pdf.text doc_t("sections.terms_and_conditions"), style: :bold, size: 11
    pdf.move_down 4
    lines.each { |line| pdf.text pdf_text(line), size: 10 }
    pdf.move_down 10
  end

  def render_pdf_company_credentials(pdf)
    documents = @company.company_documents.ordered
    return if documents.empty?

    pdf.text doc_t("sections.company_credentials"), style: :bold, size: 11
    pdf.move_down 4
    documents.each do |document|
      pdf.text pdf_text("#{document.title} (#{document.document_type_label})"), size: 10
    end
    pdf.move_down 10
  end

  def render_pdf_footer(pdf)
    footer_note = @template.resolved_footer_note(@document_kind)
    return if footer_note.blank?

    pdf.text doc_t("sections.footer"), style: :bold, size: 11
    pdf.move_down 3
    pdf.text pdf_text(footer_note), size: 10
    pdf.move_down 8
  end

  def render_pdf_signature(pdf)
    signature_image_io = template_signature_image_io
    signature_name = @template.signature_name.to_s.strip
    return unless @template.show_signature_block && (signature_image_io.present? || signature_name.present?)

    pdf.move_down 8
    pdf.text "#{doc_t('sections.signature')}:"
    if signature_image_io
      pdf.move_down 2
      pdf.image(signature_image_io, fit: [ 180, 60 ], position: :left)
      pdf.move_down 4
    end
    pdf.text "#{doc_t('labels.authorized_by')}: #{pdf_text(signature_name)}" if signature_name.present?
  end

  def render_excel_header(sheet, styles, config)
    title = @template.resolved_document_title(@document_kind)
    sheet.add_row [ title, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:title]), height: 20
    sheet.merge_cells(config.fetch("title_merge", "A1:F1"))

    left_lines = [
      excel_text(@company.name.to_s),
      excel_text(@company.address.presence || "-"),
      excel_text(@company.phone.presence || "-"),
      excel_text(@company.email.presence || "-"),
      excel_text(@company.website.presence || "-")
    ]
    right_lines = [
      excel_text("#{@template.resolved_document_number_label(@document_kind)} #{@quote.quote_no}"),
      excel_text("#{document_date_label}: #{@quote.issued_on&.strftime('%Y-%m-%d') || '-'}"),
      (@template.show_valid_until && @quote.valid_until.present? ? excel_text("Valid Until: #{@quote.valid_until.strftime('%Y-%m-%d')}") : nil),
      (@template.show_currency ? excel_text("Currency: #{@quote.currency}") : nil),
      (@quote.trade_term.present? ? excel_text("Trade Terms: #{@quote.trade_term}") : nil)
    ].compact

    [ left_lines.length, right_lines.length ].max.times do |idx|
      left_text = left_lines[idx].to_s
      right_text = right_lines[idx].to_s
      sheet.add_row [ left_text, nil, nil, right_text, nil, nil ],
                    style: [
                      (idx.zero? ? styles[:header_company_name] : styles[:header_company_meta]),
                      (idx.zero? ? styles[:header_company_name] : styles[:header_company_meta]),
                      (idx.zero? ? styles[:header_company_name] : styles[:header_company_meta]),
                      styles[:header_quote_meta],
                      styles[:header_quote_meta],
                      styles[:header_quote_meta]
                    ],
                    height: 16
      row_no = sheet.rows.size
      sheet.merge_cells("A#{row_no}:C#{row_no}")
      sheet.merge_cells("D#{row_no}:F#{row_no}")
    end

    divider_row = sheet.rows.size + 1
    sheet.add_row [ nil, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:title_underline]), height: 3
    sheet.merge_cells("A#{divider_row}:F#{divider_row}")
    sheet.add_row [ nil, nil, nil, nil, nil, nil ], height: 2
  end

  def render_excel_parties(sheet, styles)
    divider_row = sheet.rows.size + 1
    sheet.add_row [ nil, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:section_divider]), height: 4
    sheet.merge_cells("A#{divider_row}:F#{divider_row}")
    sheet.add_row [ nil, nil, nil, nil, nil, nil ], height: 3

    start_row = sheet.rows.size + 1
    sheet.add_row [ doc_t("labels.seller"), nil, nil, doc_t("labels.buyer"), nil, nil ],
                  style: [ styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block], styles[:section_block] ],
                  height: 20
    sheet.merge_cells("A#{start_row}:C#{start_row}")
    sheet.merge_cells("D#{start_row}:F#{start_row}")

    seller_lines = [
      excel_text(@company.name),
      sales_owner_display_name.present? ? excel_text("#{doc_t('labels.sales_owner')}: #{sales_owner_display_name}") : nil,
      excel_text(@company.address.presence || "-"),
      excel_text(@company.phone.presence || "-"),
      excel_text(@company.email.presence || "-"),
      excel_text(@company.website.presence || "-")
    ].compact
    buyer_lines = [
      excel_text(@customer.name),
      excel_text("#{doc_t('labels.contact')}: #{@customer.contact_name.presence || '-'}"),
      excel_text(@customer.address.presence || "-"),
      excel_text(@customer.phone.presence || "-"),
      excel_text(@customer.email.presence || "-")
    ]

    [ seller_lines.length, buyer_lines.length ].max.times do |idx|
      row_no = start_row + idx + 1
      sheet.add_row [ seller_lines[idx].to_s, nil, nil, buyer_lines[idx].to_s, nil, nil ],
                    style: [ styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell], styles[:block_cell] ],
                    height: 17
      sheet.merge_cells("A#{row_no}:C#{row_no}")
      sheet.merge_cells("D#{row_no}:F#{row_no}")
    end

    sheet.add_row [ nil, nil, nil, nil, nil, nil ], height: 5
  end

  def render_excel_items(sheet, styles)
    headers = [ doc_t("labels.no"), doc_t("labels.image"), @template.resolved_table_label("description"), @template.resolved_table_label("qty"), @template.resolved_table_label("unit_price"), @template.resolved_table_label("line_total") ]
    header_styles = [ styles[:header_left], styles[:header_left], styles[:header_left], styles[:header_right], styles[:header_right], styles[:header_right] ]
    sheet.add_row headers, style: header_styles, height: 21
    header_row_index = sheet.rows.size - 1

    image_col_index = 1
    qty_col = 3
    unit_col = 4
    total_col = 5

    @quote.quote_items.ordered.each_with_index do |item, idx|
      description_text = excel_item_description_text(item)
      row = [ idx + 1, "", description_text, item.quantity, item.unit_price.to_f, item.line_total.to_f ]
      alternate = idx.odd?
      row_styles = [
        (alternate ? styles[:cell_left_alt] : styles[:cell_left]),
        (alternate ? styles[:cell_left_alt] : styles[:cell_left]),
        (alternate ? styles[:cell_desc_alt] : styles[:cell_desc]),
        (alternate ? styles[:number_alt] : styles[:number]),
        (alternate ? styles[:currency_alt] : styles[:currency]),
        (alternate ? styles[:currency_alt] : styles[:currency])
      ]

      sheet.add_row row, style: row_styles, height: excel_item_row_height(description_text, @template.show_images?)
      row_index = sheet.rows.size - 1
      @excel_row_index_map[item.id] = row_index
      add_excel_item_image(sheet, item, image_col_index) if @template.show_images?
    end

    sheet.add_row [ nil, nil, nil, nil, nil, nil ], height: 5

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
    add_excel_total_row(sheet, doc_t("labels.subtotal"), @quote.subtotal.to_f, ctx, styles)
    add_excel_total_row(sheet, doc_t("labels.tax_vat"), @quote.tax_amount.to_f, ctx, styles) if @template.show_tax
    add_excel_total_row(sheet, doc_t("labels.shipping"), @quote.shipping_amount.to_f, ctx, styles) if @template.show_shipping
    add_excel_total_row(sheet, doc_t("labels.discount"), @quote.discount_amount.to_f, ctx, styles)

    row = summary_row_data(doc_t("labels.grand_total"), @quote.grand_total.to_f, ctx[:width], ctx[:label_col], ctx[:value_col])
    style = summary_row_styles(ctx[:width], ctx[:label_col], ctx[:value_col], styles[:grand_total_label], styles[:grand_total])
    sheet.add_row row, style: style, height: 22

    totals_end = sheet.rows.size
    (totals_start..totals_end).each do |row_no|
      sheet.merge_cells("A#{row_no}:C#{row_no}")
      sheet.merge_cells("D#{row_no}:E#{row_no}")
    end
  end

  def render_excel_sections(sheet, styles)
    if @template.show_terms_section
      terms_rows = []
      terms_rows << [ doc_t("labels.payment_terms"), @quote.payment_term ] if @template.show_payment_term && @quote.payment_term.present?
      terms_rows << [ doc_t("labels.trade_terms"), @quote.trade_term ] if @quote.trade_term.present?
      terms_rows << [ doc_t("labels.terms"), @quote.terms_text ] if @quote.terms_text.present?
      terms_rows << [ doc_t("labels.legal_disclaimer"), @quote.legal_disclaimer ] if @quote.legal_disclaimer.present?
      terms_rows << [ doc_t("labels.delivery_notes"), @quote.delivery_notes ] if @quote.delivery_notes.present?

      if terms_rows.any?
        divider_row = sheet.rows.size + 1
        sheet.add_row [ nil, nil, nil, nil, nil, nil ], style: Array.new(6, styles[:terms_divider]), height: 4
        sheet.merge_cells("A#{divider_row}:F#{divider_row}")
        sheet.add_row [ nil, nil, nil, nil, nil, nil ], height: 4
        sheet.add_row [ doc_t("sections.terms_and_conditions") ], style: styles[:section]
        sheet.merge_cells("A#{sheet.rows.size}:F#{sheet.rows.size}")

        terms_rows.each do |label, value|
          add_excel_terms_row(sheet, styles, label, value)
        end
      end
    end

    if @template.show_notes && @quote.notes.present?
      sheet.add_row []
      add_excel_terms_row(sheet, styles, doc_t("labels.notes"), @quote.notes)
    end

    footer_note = @template.resolved_footer_note(@document_kind)
    if footer_note.present?
      sheet.add_row []
      add_excel_terms_row(sheet, styles, doc_t("sections.footer"), footer_note)
    end
  end

  def apply_excel_sheet_options(sheet)
    if sheet.sheet_view.respond_to?(:show_grid_lines=)
      sheet.sheet_view.show_grid_lines = !!@template.excel_show_grid_lines
    end
  rescue StandardError
    nil
  end

  def apply_excel_post_layout(sheet, ctx, config)
    widths = (config["column_widths"] || [ 6, 14, 42, 8, 14, 16 ]).map(&:to_f)
    widths[0] = [ widths[0], 6 ].max
    widths[1] = [ widths[1], 8 ].max
    widths[2] = [ widths[2], 64 ].max
    widths[3] = [ widths[3], 8 ].max
    widths[4] = [ widths[4], 15 ].max
    widths[5] = [ widths[5], 17 ].max
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
    dark_header = accent
    grid = "E5E7EB"
    emphasis = "6B7280"
    zebra = "F8FAFC"
    grand_total_fill = "EAF2FF"
    grand_total_text = "1E3A5F"
    currency_format_code = excel_currency_format_code

    {
      title: styles.add_style(sz: 15, b: true, fg_color: accent, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      title_underline: styles.add_style(border: { style: :thin, color: accent, edges: [ :bottom ] }, font_name: font),
      section_divider: styles.add_style(border: { style: :thin, color: grid, edges: [ :top ] }, font_name: font),
      header_company_name: styles.add_style(sz: 12, b: true, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      header_company_meta: styles.add_style(sz: 11, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      header_quote_meta: styles.add_style(sz: 11, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      section: styles.add_style(sz: 12, b: true, fg_color: accent, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      section_block: styles.add_style(sz: 11, b: true, fg_color: "334155", alignment: { horizontal: :left, vertical: :center }, font_name: font),
      block_cell: styles.add_style(sz: 11, alignment: { horizontal: :left, vertical: :top, wrap_text: true }, font_name: font),
      meta_label: styles.add_style(sz: 11, b: true, fg_color: "334155", alignment: { horizontal: :left, vertical: :top, wrap_text: true }, font_name: font),
      terms_value: styles.add_style(sz: 11, alignment: { horizontal: :left, vertical: :top, wrap_text: true }, font_name: font),
      header_left: styles.add_style(sz: 11, b: true, bg_color: dark_header, fg_color: "FFFFFF", border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :left, vertical: :center }, font_name: font),
      header_right: styles.add_style(sz: 11, b: true, bg_color: dark_header, fg_color: "FFFFFF", border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      cell_left: styles.add_style(sz: 11, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :left, vertical: :center, wrap_text: true }, font_name: font),
      cell_left_alt: styles.add_style(sz: 11, bg_color: zebra, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :left, vertical: :center, wrap_text: true }, font_name: font),
      cell_desc: styles.add_style(sz: 11, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :left, vertical: :top, wrap_text: true }, font_name: font),
      cell_desc_alt: styles.add_style(sz: 11, bg_color: zebra, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, alignment: { horizontal: :left, vertical: :top, wrap_text: true }, font_name: font),
      number: styles.add_style(sz: 11, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, format_code: "0", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      number_alt: styles.add_style(sz: 11, bg_color: zebra, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, format_code: "0", alignment: { horizontal: :right, vertical: :center }, font_name: font),
      currency: styles.add_style(sz: 11, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, format_code: currency_format_code, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      currency_alt: styles.add_style(sz: 11, bg_color: zebra, border: { style: :thin, color: grid, edges: [ :left, :right, :bottom ] }, format_code: currency_format_code, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      totals_separator: styles.add_style(border: { style: :medium, color: emphasis, edges: [ :top ] }, font_name: font),
      total_label: styles.add_style(sz: 11, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      total_value: styles.add_style(sz: 11, format_code: currency_format_code, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      grand_total_label: styles.add_style(b: true, sz: 12, bg_color: grand_total_fill, fg_color: grand_total_text, border: { style: :medium, color: emphasis, edges: [ :top ] }, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      grand_total: styles.add_style(b: true, sz: 13, bg_color: grand_total_fill, fg_color: grand_total_text, border: { style: :medium, color: emphasis, edges: [ :top ] }, format_code: currency_format_code, alignment: { horizontal: :right, vertical: :center }, font_name: font),
      terms_divider: styles.add_style(border: { style: :thin, color: grid, edges: [ :top ] }, font_name: font)
    }
  end

  def excel_number_format_code
    decimals = @template&.amount_decimals.to_i
    decimals = 2 unless [ 0, 2 ].include?(decimals)
    decimal_suffix = decimals.zero? ? "" : ".#{'0' * decimals}"

    integer_part =
      case @template&.thousand_separator
      when "none" then "0"
      when "space" then "# ##0"
      else "#,##0"
      end

    "#{integer_part}#{decimal_suffix}"
  end

  def excel_currency_format_code
    base = excel_number_format_code
    return base unless @template.show_currency

    code = @quote.currency.to_s.upcase.presence || "USD"
    symbol = Quote.currency_symbol_for(code)
    mode = @template&.currency_display_mode.presence || "symbol_prefix"

    case mode
    when "code_prefix"
      "#{excel_format_literal(code)} #{base}"
    when "code_suffix"
      "#{base} #{excel_format_literal(code)}"
    else
      literal = (symbol == code ? code : symbol)
      "#{excel_format_literal(literal)}#{base}"
    end
  end

  # Excel custom number format must avoid raw double quotes inside XML attributes.
  # Use escaped literals (\U\S\D) instead of quoted strings ("USD") to keep styles.xml valid.
  def excel_format_literal(text)
    text.to_s.each_char.map { |char| "\\#{char}" }.join
  end

  def add_excel_terms_row(sheet, styles, label, value)
    row = sheet.rows.size + 1
    sheet.add_row [ label, nil, value, nil, nil, nil ],
                  style: [ styles[:meta_label], styles[:meta_label], styles[:terms_value], styles[:terms_value], styles[:terms_value], styles[:terms_value] ],
                  height: 17
    sheet.merge_cells("A#{row}:B#{row}")
    sheet.merge_cells("C#{row}:F#{row}")
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
    return unless product_display_attachment(item.product)

    image_path = excel_image_path_for(item)
    return if image_path.blank?

    row_index = @excel_row_index_map[item.id] || sheet.rows.size - 1
    current_height = sheet.rows[row_index].height.to_f
    sheet.rows[row_index].height = [ current_height, 40 ].max

    sheet.add_image(image_src: image_path) do |image|
      image.start_at(image_col_index, row_index)
      image.width = 34
      image.height = 34
    end
  rescue StandardError
    nil
  end

  def excel_image_path_for(item)
    attachment = product_display_attachment(item.product)
    return nil unless attachment

    blob = attachment.blob
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
    headers = [ doc_t("labels.no") ]
    headers << doc_t("labels.image") if @template.show_images?
    headers.concat([ @template.resolved_table_label("description"), @template.resolved_table_label("qty"), @template.resolved_table_label("unit_price"), @template.resolved_table_label("line_total") ])
  end

  def pdf_image_cell(item)
    return "-" unless @template.show_images?
    attachment = product_display_attachment(item.product)
    return "-" unless attachment

    path = ActiveStorage::Blob.service.path_for(attachment.blob.key)
    { image: path, fit: [ 38, 38 ], position: :center, vposition: :center }
  rescue StandardError
    doc_t("labels.image")
  end

  def product_display_attachment(product)
    return nil unless product
    return product.image_attachment if product.image_attachment.present?

    product.gallery_images.attachments.first
  end

  def configure_pdf_font(pdf)
    @pdf_font_unicode_ready = false
    candidates = (FONT_MAP.fetch(@template.font_family, []) + FONT_MAP["Noto Sans"] + extra_pdf_font_candidates).uniq

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
        @pdf_font_unicode_ready = true
        return
      rescue StandardError
        next
      end
    end
  end

  def extra_pdf_font_candidates
    [
      ENV["QUOTE_PDF_FONT_PATH"],
      "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
      "/usr/local/share/fonts/noto-cjk/NotoSansCJKsc-Regular.otf",
      "/usr/share/fonts/truetype/noto/NotoSansSC-Regular.ttf",
      "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
      "/usr/share/fonts/truetype/arphic/ukai.ttc",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ].compact
  end

  def excel_template_config
    require "yaml"

    path = Rails.root.join("app/templates/excel/#{@template.layout_type}.yml")
    YAML.load_file(path)
  rescue StandardError
    {
      "sheet_name" => xlsx_sheet_name,
      "column_widths" => [ 6, 14, 42, 8, 14, 16 ],
      "title_merge" => "A1:F1"
    }
  end

  def excel_item_row_height(description_text, with_images)
    line_count = description_text.to_s.split(/\r?\n/).count
    visible_lines = [ line_count, 1 ].max
    base_height = 24 + (visible_lines * 18)
    base_height = [ base_height, 64 ].max if with_images
    [ [ base_height, 32 ].max, 260 ].min
  end

  def xlsx_sheet_name
    @document_kind == "pi" ? doc_t("sheet.pi") : doc_t("sheet.quote")
  end

  def document_date_label
    @document_kind == "pi" ? doc_t("labels.pi_date") : doc_t("labels.quote_date")
  end

  def total_value_text(value)
    pdf_text(money_text(value))
  end

  def money_text(value)
    amount = decimal_text(value)
    return amount unless @template.show_currency

    symbol = Quote.currency_symbol_for(@quote.currency)
    symbol == @quote.currency.to_s.upcase ? "#{symbol} #{amount}" : "#{symbol}#{amount}"
  end

  def pdf_item_description_text(item)
    lines = [ item.description.to_s ]
    item.specification_pairs.each do |pair|
      lines << "#{doc_t('labels.spec')}: #{pair[:key]} - #{pair[:value]}"
    end
    item.addon_charge_entries.each do |entry|
      lines << "#{doc_t('labels.addon')}: #{entry[:name]} (#{money_text(entry[:amount])})"
    end
    lines.join("\n")
  end

  def excel_item_description_text(item)
    title = item.product&.name.presence || item.description.to_s.presence || doc_t("labels.item")
    lines = [ title ]
    if item.description.present? && item.description.to_s != title
      lines << item.description.to_s
    end
    item.specification_pairs.each do |pair|
      lines << "#{doc_t('labels.spec')}: #{pair[:key]} - #{pair[:value]}"
    end
    item.addon_charge_entries.each do |entry|
      lines << "  #{doc_t('labels.addon')}: #{entry[:name]} (#{money_text(entry[:amount])})"
    end
    lines.join("\n")
  end

  def doc_t(key, **options)
    I18n.t("quote_document.#{key}", **options)
  end

  def pdf_text(value)
    text = value.to_s
    return text if @pdf_font_unicode_ready

    text.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  rescue StandardError
    text.scrub("?")
  end

  def decimal_text(value)
    format("%.2f", value.to_d)
  end

  def excel_text(value)
    text = value.to_s
    return text if text.blank?
    return "'#{text}" if text.match?(/\A\+?[\d\-\s()]+\z/)

    text
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

  def sales_owner_display_name
    return nil unless @template.show_customer_owner
    return nil unless @customer.respond_to?(:internal_owner_display_name)

    value = @customer.internal_owner_display_name.to_s
    return nil if value.blank? || value == "-"

    value
  end

  def template_signature_image_io
    return nil unless @template.respond_to?(:signature_image) && @template.signature_image.attached?

    decoded = @template.signature_image.blob.download
    return nil if decoded.blank?

    io = StringIO.new(decoded)
    io.set_encoding(Encoding::BINARY) if io.respond_to?(:set_encoding)
    io
  rescue StandardError
    nil
  end

  def template_watermark_image_io
    return nil unless @template.respond_to?(:watermark_image) && @template.watermark_image.attached?

    decoded = @template.watermark_image.blob.download
    return nil if decoded.blank?

    io = StringIO.new(decoded)
    io.set_encoding(Encoding::BINARY) if io.respond_to?(:set_encoding)
    io
  rescue StandardError
    nil
  end

  def pdf_watermark_text
    return nil if @template.respond_to?(:watermark_image) && @template.watermark_image.attached?

    @template.watermark_text.to_s.strip.presence || @company.name.to_s.strip.presence || "CONFIDENTIAL"
  end

  def watermark_alpha
    percent = @template.respond_to?(:watermark_opacity) ? @template.watermark_opacity.to_i : 12
    percent = 12 if percent <= 0
    [ [ percent, 3 ].max, 40 ].min / 100.0
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
