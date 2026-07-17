namespace :visual_review do
  desc "Create deterministic, non-production evidence data"
  task seed: :environment do
    puts JSON.pretty_generate(VisualReviewSeeder.call)
  end

  desc "Generate auditable PDF, Excel, final-document, email and difference evidence"
  task evidence: :environment do
    raise "Visual review evidence is test-only" unless Rails.env.test?
    output = Rails.root.join("tmp/visual-review/generated")
    FileUtils.mkdir_p(output)
    company = Company.find_by!(slug: "visual-review-machinery")
    deal = company.quotes.find_by!(quote_no: "VR-E2E-001")
    revision = deal.quote_revisions.ordered.first || RevisionPublisher.new(quote: deal, actor: company.users.first).call.revision
    generator = PublishedVersionFileGenerator.new(revision)
    published_pdf = generator.pdf
    published_excel = generator.excel
    output.join(published_pdf.filename).binwrite(published_pdf.io.read)
    original_workbook = published_excel.io.read
    output.join(published_excel.filename).binwrite(original_workbook)

    acceptance = deal.quote_acceptance || QuoteAcceptor.new(revision:, attributes: { name: "Anna Evidence", email: "anna@example.com" },
      selection: {}, idempotency_key: "visual-evidence-acceptance").call
    document = FinalDocumentGenerator.new(acceptance:, actor: company.users.first, document_type: "order_confirmation").call
    output.join(document.file.filename.to_s).binwrite(document.file.download)

    delivery = revision.version_deliveries.new(company:, quote: deal, created_by: company.users.first,
      channel: "email_link", recipient: "buyer@example.com", subject: "Version #{revision.number}",
      message_body: "Review the immutable commercial Version.", status: "draft", idempotency_key: "visual-email-preview")
    email = VersionDeliveryMailer.with(delivery:).deliver_version
    output.join("email-preview.html").write(email.html_part&.body&.decoded || email.body.decoded)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Published quote") do |sheet|
      sheet.add_row [ "Rubusoo Published Version" ]
      sheet.add_row [ "Deal ID", deal.id, "Version ID", revision.id ]
      sheet.add_row [ "Buyer", revision.snapshot["customer_name"], "Currency", revision.currency ]
      sheet.add_row []
      sheet.add_row %w[Line_ID SKU Description Specifications Quantity Unit Unit_price Discount Amount]
      Array(revision.snapshot["quote_items"]).reverse.each_with_index do |item, index|
        quantity = item["quantity"].to_d + (index.zero? ? 2 : 0)
        price = item["unit_price"].to_d + (index.zero? ? 125 : 0)
        sheet.add_row [ item["id"], item["sku_snapshot"], item["description"], "Voltage: 400V / 50Hz", quantity,
          item["unit_snapshot"], price, item["discount_amount"], quantity * price ]
      end
      sheet.add_row []
      sheet.add_row [ "Shipping", revision.snapshot["shipping_amount"].to_d + 450 ]
      sheet.add_row [ "Incoterm", "CIF Hamburg" ]
      sheet.add_row [ "Payment terms", "30% deposit, 70% before shipment" ]
    end
    package.workbook.add_worksheet(name: "Rubusoo metadata") do |sheet|
      canonical = lambda do |value|
        value.is_a?(Hash) ? value.keys.sort.to_h { |key| [ key, canonical.call(value[key]) ] } :
          (value.is_a?(Array) ? value.map { |entry| canonical.call(entry) } : value)
      end
      sheet.add_row [ "deal_id", deal.id ]
      sheet.add_row [ "version_id", revision.id ]
      sheet.add_row [ "secure_fingerprint", Digest::SHA256.hexdigest(canonical.call(revision.snapshot).to_json) ]
    end
    returned_binary = package.to_stream.read
    output.join("buyer-modified-#{published_excel.filename}").binwrite(returned_binary)
    returned = deal.deal_responses.find_or_initialize_by(idempotency_key: "visual-returned-workbook")
    returned.assign_attributes(company:, quote_revision: revision, recorded_by: company.users.first, kind: "returned_excel",
      source: "excel", body: "Buyer increased quantity and requested 400V.", received_at: Time.current)
    returned.attachment.attach(io: StringIO.new(returned_binary), filename: "buyer-modified.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") unless returned.attachment.attached?
    returned.save!
    returned.update!(difference_review: DealResponseAnalyzer.new(returned).call)

    po_pdf = Prawn::Document.new
    po_pdf.text "Purchase Order: HPG-8842"
    po_pdf.text "Currency: USD"
    po_pdf.text "Incoterm: CIF Hamburg"
    po_pdf.text "Payment terms: Net 45"
    po_pdf.text "Grand total: USD #{revision.total.to_d + 9_500}"
    po_binary = po_pdf.render
    output.join("buyer-purchase-order-HPG-8842.pdf").binwrite(po_binary)
    po = deal.deal_responses.find_or_initialize_by(idempotency_key: "visual-po-attachment")
    po.assign_attributes(company:, quote_revision: revision, recorded_by: company.users.first, kind: "purchase_order",
      source: "purchase_order", body: "", received_at: Time.current)
    po.attachment.attach(io: StringIO.new(po_binary), filename: "HPG-8842.pdf", content_type: "application/pdf") unless po.attachment.attached?
    po.save!
    po.update!(difference_review: DealResponseAnalyzer.new(po).call)

    po_report = po.difference_review
    returned_report = returned.difference_review
    raise "PO comparison evidence is empty" if po_report["changes"].blank?
    raise "Returned workbook evidence is empty" if returned_report["changes"].blank?
    output.join("po-comparison-report.json").write(JSON.pretty_generate(po_report))
    output.join("returned-excel-difference-report.json").write(JSON.pretty_generate(returned_report))
    puts "Generated evidence in #{output}"
  end
end
