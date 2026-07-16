class VisualReviewSeeder
  PASSWORD = "RubusooVisual!2026"

  def self.call
    raise "Visual review seed is test-only" unless Rails.env.test?
    new.call
  end

  def call
    company = Company.find_or_create_by!(slug: "visual-review-machinery") do |record|
      record.name = "Northstar Motion Systems"
      record.email = "export@northstar.example"
      record.default_currency = "USD"
      record.plan = "business"
      record.subscription_status = "active"
      record.trial_ends_at = 1.year.from_now
    end
    company.update!(plan: "business", subscription_status: "active", require_final_document: false,
      require_deposit_workflow: false, default_final_document_type: "order_confirmation")
    user = company.users.find_or_initialize_by(email: "visual@rubusoo.example")
    user.assign_attributes(username: "visual_auditor", password: PASSWORD, password_confirmation: PASSWORD,
      company_role: "owner", email_verified_at: Time.current)
    user.save!
    buyer = company.customers.find_or_create_by!(email: "anna@helix-hamburg.example") do |record|
      record.name = "Helix Process GmbH"
      record.contact_name = "Anna Keller"
      record.country = "Germany"
    end
    products = seed_products(company)
    deal = company.quotes.find_by(quote_no: "VR-CHANNEL-001") || build_deal(company, buyer, products, "VR-CHANNEL-001")
    version_one, version_two = seed_versions(deal, user)
    seed_channel_history(deal, version_two, user)
    edge_deals = seed_edge_deals(company, buyer, products, user)
    payload = {
      "email" => user.email, "password" => PASSWORD, "deal_id" => deal.id,
      "version_one_id" => version_one.id, "version_two_id" => version_two.id,
      "buyer_token" => version_two.secure_token, "old_buyer_token" => version_one.secure_token,
      "edge_deals" => edge_deals.transform_values(&:id)
    }
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    Rails.root.join("tmp/visual_review_seed.json").write(JSON.pretty_generate(payload))
    payload
  end

  private

  def seed_products(company)
    [
      [ "NSM-CUT-480", "CNC Fiber Laser Cutting Cell", 48_600, "Industrial 6kW cutting platform" ],
      [ "NSM-FDR-12", "Servo Coil Feeding Line", 18_400, "Precision synchronized material feed" ],
      [ "NSM-VLT-02", "Automatic Voltage Stabilizer", 2_850, "380V three-phase power conditioning" ]
    ].map do |sku, name, price, description|
      company.products.find_or_create_by!(sku:) do |product|
        product.name = name; product.description = description; product.default_price = price; product.price_currency = "USD"
      end
    end
  end

  def build_deal(company, buyer, products, quote_no)
    deal = company.quotes.new(customer: buyer, quote_no:, currency: "USD", status: "draft",
      custom_title: "Hamburg Smart Fabrication Line", issued_on: Date.new(2026, 7, 16),
      valid_until: Date.new(2026, 8, 15), trade_term: "CIF Hamburg", payment_term: "30% deposit, 70% before shipment",
      shipping_amount: 4_800, shipping_price_source: "freight_forwarder_quote", notes: "Commissioning support included.")
    products.each_with_index do |product, index|
      deal.quote_items.build(product:, description: product.name, quantity: index.zero? ? 1 : 2,
        unit_price: product.default_price, price_source: "catalog", unit_snapshot: "set",
        specifications: [ { key: "Voltage", value: "380V / 50Hz / 3Ph" }, { key: "Destination", value: "Hamburg" } ])
    end
    deal.save!
    deal
  end

  def seed_versions(deal, user)
    return [ deal.quote_revisions.find_by(number: 1), deal.quote_revisions.find_by(number: 2) ] if deal.quote_revisions.count >= 2
    first = RevisionPublisher.new(quote: deal, actor: user).call.revision
    first.version_deliveries.create!(company: deal.company, quote: deal, created_by: user, channel: "email_link_pdf",
      recipient: deal.customer.email, delivered_at: Time.zone.parse("2026-07-16 09:30"), idempotency_key: "visual-v1-email")
    deal.quote_items.first.update!(quantity: 2)
    deal.update!(shipping_amount: 5_200, status: "draft")
    second = RevisionPublisher.new(quote: deal, actor: user).call.revision
    second.version_deliveries.create!(company: deal.company, quote: deal, created_by: user, channel: "external",
      external_channel: "whatsapp", recipient: "Anna Keller", note: "Version 2 sent in buyer procurement group",
      delivered_at: Time.zone.parse("2026-07-16 11:45"), idempotency_key: "visual-v2-whatsapp")
    deal.update!(status: "sent", sent_at: Time.zone.parse("2026-07-16 11:45"))
    [ first, second ]
  end

  def seed_channel_history(deal, version, user)
    version.buyer_questions.find_or_create_by!(idempotency_key: "visual-voltage-question") do |question|
      question.company = deal.company; question.context_type = "configuration"; question.context_key = "Voltage"
      question.buyer_name = "Anna Keller"; question.buyer_email = deal.customer.email
      question.body = "Can the stabilizer support a 400V plant supply?"; question.seller_reply = "Yes, we will include the 380–415V input module."
      question.replied_at = Time.zone.parse("2026-07-16 12:20")
    end
    deal.deal_responses.find_or_create_by!(idempotency_key: "visual-po-response") do |response|
      response.company = deal.company; response.quote_revision = version; response.recorded_by = user
      response.kind = "purchase_order"; response.source = "purchase_order"; response.buyer_name = "Anna Keller"
      response.body = "PO HPG-7742 · total USD 148250 · delivery CIF Hamburg"; response.received_at = Time.zone.parse("2026-07-16 13:10")
      response.difference_review = { "severity" => "material_difference", "review_required" => true }
    end
  end

  def seed_edge_deals(company, buyer, products, user)
    {
      "missing_price" => edge_deal(company, buyer, products.first, "VR-EDGE-PRICE", "Replacement cutting head — price required", 0),
      "no_image" => edge_deal(company, buyer, products.last, "VR-EDGE-IMAGE", "Voltage conditioning package", 2_850),
      "long_quote" => long_deal(company, buyer, products.first, user),
      "delivery_failure" => failed_delivery_deal(company, buyer, products.second, user),
      "closed" => closed_deal(company, buyer, products.last, user)
    }
  end

  def edge_deal(company, buyer, product, number, title, price)
    existing = company.quotes.find_by(quote_no: number)
    if existing
      existing.quote_items.first&.update_columns(unit_price: 0) if price.zero?
      return existing
    end
    deal = company.quotes.create!(customer: buyer, quote_no: number,
      currency: "USD", status: "draft", custom_title: title, issued_on: Date.current, valid_until: 30.days.from_now,
      quote_items_attributes: [ { product_id: product.id, description: title, quantity: 1, unit_price: price.zero? ? 1 : price,
        price_source: price.zero? ? "manual" : "catalog" } ])
    deal.quote_items.first.update_columns(unit_price: 0) if price.zero?
    deal
  end

  def long_deal(company, buyer, product, user)
    deal = company.quotes.find_by(quote_no: "VR-EDGE-50")
    return deal if deal
    deal = company.quotes.new(customer: buyer, quote_no: "VR-EDGE-50", currency: "USD", status: "draft",
      custom_title: "50-line spare parts and commissioning package", issued_on: Date.current, valid_until: 30.days.from_now,
      trade_term: "EXW", payment_term: "Payment before dispatch")
    50.times { |index| deal.quote_items.build(product:, description: "Precision service component #{(index + 1).to_s.rjust(2, '0')}", quantity: index + 1, unit_price: 25 + index, price_source: "catalog") }
    deal.save!; deal
  end

  def failed_delivery_deal(company, buyer, product, user)
    deal = edge_deal(company, buyer, product, "VR-EDGE-FAIL", "Feeding line replacement package", 18_400)
    return deal if deal.quote_revisions.any?
    deal.update!(trade_term: "FOB Shanghai", payment_term: "100% before shipment")
    version = RevisionPublisher.new(quote: deal, actor: user).call.revision
    version.version_deliveries.create!(company:, quote: deal, created_by: user, channel: "email_pdf", status: "failed",
      recipient: "procurement@helix-hamburg.example", note: "Mailbox rejected attachment size", delivered_at: Time.current,
      idempotency_key: "visual-failed-delivery")
    deal.update!(status: "sent")
    deal
  end

  def closed_deal(company, buyer, product, user)
    deal = edge_deal(company, buyer, product, "VR-EDGE-CLOSED", "Accepted power conditioning order", 2_850)
    deal.update!(status: "won", final_amount: deal.grand_total, win_reason: "price_accepted", won_at: Time.current)
    deal
  end
end
