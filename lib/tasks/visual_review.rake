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
    [ generator.pdf, generator.excel ].each { |file| output.join(file.filename).binwrite(file.io.read) }

    acceptance = deal.quote_acceptance || QuoteAcceptor.new(revision:, attributes: { name: "Anna Evidence", email: "anna@example.com" },
      selection: {}, idempotency_key: "visual-evidence-acceptance").call
    document = FinalDocumentGenerator.new(acceptance:, actor: company.users.first, document_type: "order_confirmation").call
    output.join(document.file.filename.to_s).binwrite(document.file.download)

    delivery = revision.version_deliveries.new(company:, quote: deal, created_by: company.users.first,
      channel: "email_link", recipient: "buyer@example.com", subject: "Version #{revision.number}",
      message_body: "Review the immutable commercial Version.", status: "draft", idempotency_key: "visual-email-preview")
    email = VersionDeliveryMailer.with(delivery:).deliver_version
    output.join("email-preview.html").write(email.html_part&.body&.decoded || email.body.decoded)
    output.join("po-comparison-report.json").write(JSON.pretty_generate(deal.deal_responses.where(kind: "purchase_order").first&.difference_review || {}))
    returned = deal.deal_responses.where(kind: "returned_excel").first
    output.join("returned-excel-difference-report.json").write(JSON.pretty_generate(returned&.difference_review || { status: "No returned workbook in this scenario" }))
    puts "Generated evidence in #{output}"
  end
end
