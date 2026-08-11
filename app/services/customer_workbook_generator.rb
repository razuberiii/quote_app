require "zip"

class CustomerWorkbookGenerator
  MAX_PACKAGE_ENTRIES = 5_000
  MAX_EXPANDED_SIZE = 50.megabytes
  Result = Data.define(:io, :filename, :content_type, :byte_size)

  def initialize(revision, workbook_template)
    @revision = revision
    @template = workbook_template
    raise ArgumentError, "Workbook template does not belong to this quote" unless @template.company_id == @revision.company_id
    expected = @revision.snapshot.dig("workbook_template", "id")
    raise ArgumentError, "Workbook template was not selected for this version" unless expected.to_i == @template.id
    raise ArgumentError, "Workbook template file changed after publication" unless @revision.snapshot.dig("workbook_template", "checksum") == @template.workbook.blob.checksum
  end

  def generate
    entries = read_package
    sheet_path = worksheet_path(entries)
    document = Nokogiri::XML(entries.fetch(sheet_path))
    sheet_data = document.at_xpath("//*[local-name()='worksheet']/*[local-name()='sheetData']") || raise(ArgumentError, "Workbook has no worksheet data")

    scalar_values.each do |key, value|
      cell = @template.field_mappings.to_h[key]
      write_cell(sheet_data, cell, value) if cell.present?
    end
    @template.custom_field_definitions.each do |field|
      write_cell(sheet_data, field[:cell], snapshot.fetch("custom_field_values", {})[field[:key].to_s])
    end
    write_items(sheet_data)

    entries[sheet_path] = document.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    binary = write_package(entries)
    filename = "#{@revision.quote.quote_no}-V#{@revision.number}-#{safe_filename(@template.name)}.xlsx"
    Result.new(StringIO.new(binary), filename, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", binary.bytesize)
  end

  private

  def snapshot = @revision.snapshot

  def scalar_values
    {
      "quote_number" => @revision.quote.quote_no,
      "issued_on" => (@revision.sent_at || @revision.published_at)&.to_date&.iso8601,
      "valid_until" => @revision.expires_at&.to_date&.iso8601,
      "seller_name" => snapshot.dig("seller_company", "name"),
      "seller_address" => snapshot.dig("seller_company", "address"),
      "customer_name" => snapshot["customer_name"],
      "customer_contact" => snapshot["customer_contact_name"],
      "customer_address" => snapshot["customer_address"],
      "currency" => @revision.currency,
      "subtotal" => snapshot["subtotal"],
      "shipping" => snapshot["shipping_amount"],
      "discount" => snapshot["discount_amount"],
      "tax" => snapshot["tax_amount"],
      "total" => @revision.total,
      "payment_term" => snapshot["payment_term"],
      "trade_term" => snapshot["trade_term"],
      "delivery_notes" => snapshot["delivery_notes"]
    }
  end

  def write_items(sheet_data)
    mapping = @template.item_mapping.to_h
    start_row = mapping["start_row"].to_i
    columns = mapping.fetch("columns", {})
    return if start_row < 1 || columns.empty?

    template_row = row_at(sheet_data, start_row)&.dup(1)
    Array(snapshot["quote_items"]).each_with_index do |item, index|
      row_number = start_row + index
      row = row_at(sheet_data, row_number) || clone_or_create_row(sheet_data, template_row, row_number)
      values = item_values(item)
      columns.each { |key, column| write_cell(row, "#{column}#{row_number}", values[key]) }
    end
  end

  def item_values(item)
    quantity = item["quantity"].to_d
    unit_price = item["unit_price"].to_d
    discount = item["discount_amount"].to_d
    {
      "sku" => item["sku_snapshot"],
      "description" => item["product_name"].presence || item["description"],
      "specifications" => Array(item["specifications"]).map { |spec| "#{spec['key'] || spec['name']}: #{spec['value']}" }.join(" | "),
      "quantity" => quantity,
      "unit" => item["unit_snapshot"],
      "unit_price" => unit_price,
      "discount" => discount,
      "amount" => quantity * unit_price - discount
    }
  end

  def read_package
    @template.workbook.open do |file|
      Zip::File.open(file.path) do |zip|
        raise ArgumentError, "Workbook contains too many files" if zip.entries.size > MAX_PACKAGE_ENTRIES
        expanded_size = 0
        zip.to_h do |entry|
          content = entry.get_input_stream.read
          expanded_size += content.bytesize
          raise ArgumentError, "Workbook expands beyond 50 MB" if expanded_size > MAX_EXPANDED_SIZE
          [ entry.name, content ]
        end
      end
    end
  end

  def worksheet_path(entries)
    workbook = Nokogiri::XML(entries.fetch("xl/workbook.xml"))
    workbook.remove_namespaces!
    requested = @template.item_mapping.to_h["sheet"].presence
    sheet = requested ? workbook.xpath("//workbook/sheets/sheet").find { |node| node["name"] == requested } : workbook.at_xpath("//workbook/sheets/sheet")
    raise ArgumentError, "Worksheet #{requested.inspect} was not found" unless sheet

    relationship_id = sheet["id"] || sheet["r:id"]
    relationships = Nokogiri::XML(entries.fetch("xl/_rels/workbook.xml.rels"))
    relationships.remove_namespaces!
    relationship = relationships.xpath("//Relationships/Relationship").find { |node| node["Id"] == relationship_id }
    raise ArgumentError, "Worksheet relationship is missing" unless relationship

    "xl/#{relationship['Target'].sub(%r{\A/}, '').sub(%r{\Axl/}, '')}"
  end

  def write_package(entries)
    buffer = Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end
    buffer.string
  end

  def write_cell(scope, reference, value)
    return if reference.blank?
    reference = reference.to_s.upcase
    row_number = reference[/\d+/].to_i
    sheet_data = scope.name == "sheetData" ? scope : scope.ancestors.find { |node| node.name == "sheetData" }
    row = scope.name == "row" && scope["r"].to_i == row_number ? scope : row_at(sheet_data, row_number)
    row ||= clone_or_create_row(sheet_data, nil, row_number)
    cell = row.xpath("./*[local-name()='c']").find { |node| node["r"] == reference }
    unless cell
      cell = namespaced_node("c", row)
      cell["r"] = reference
      row.add_child(cell)
    end
    cell.xpath("./*[local-name()='v' or local-name()='is' or local-name()='f']").remove
    if numeric?(value)
      cell.remove_attribute("t")
      value_node = namespaced_node("v", row)
      value_node.content = value.to_d.to_s("F")
      cell.add_child(value_node)
    else
      cell["t"] = "inlineStr"
      inline = namespaced_node("is", row)
      text = namespaced_node("t", row)
      text.content = value.to_s
      inline.add_child(text)
      cell.add_child(inline)
    end
  end

  def numeric?(value) = value.is_a?(Numeric) || value.is_a?(BigDecimal)

  def row_at(sheet_data, number)
    sheet_data&.xpath("./*[local-name()='row']")&.find { |node| node["r"].to_i == number }
  end

  def clone_or_create_row(sheet_data, template_row, number)
    row = template_row ? template_row.dup(1) : namespaced_node("row", sheet_data)
    row["r"] = number.to_s
    row.xpath("./*[local-name()='c']").each { |cell| cell["r"] = "#{cell['r'][/\A[A-Z]+/]}#{number}" }
    following = sheet_data.xpath("./*[local-name()='row']").find { |candidate| candidate["r"].to_i > number }
    following ? following.add_previous_sibling(row) : sheet_data.add_child(row)
    row
  end

  def namespaced_node(name, parent)
    node = Nokogiri::XML::Node.new(name, parent.document)
    node.namespace = parent.namespace || parent.document.root.namespace
    node
  end

  def safe_filename(value)
    value.to_s.gsub(/[^0-9A-Za-z\p{Han}._-]+/u, "-").gsub(/\A-+|-+\z/, "").presence || "customer-template"
  end
end
