require "test_helper"

class ChannelNeutralDealFlowTest < ActiveSupport::TestCase
  setup do
    PublishedVersionDatabaseGuard.install!
    @company = companies(:one)
    @company.update!(plan: "pro", subscription_status: "active", trial_ends_at: 10.days.from_now,
      require_final_document: false, require_deposit_workflow: false)
    @user = users(:one)
    @quote = quotes(:one)
    @quote.update!(status: "draft", valid_until: 30.days.from_now, trade_term: "CIF Hamburg",
      payment_term: "30% deposit, 70% before shipment", shipping_amount: 350,
      shipping_price_source: "freight_forwarder_quote")
    @version = RevisionPublisher.new(quote: @quote, actor: @user).call.revision
  end

  test "published version remains draft stage until a delivery succeeds" do
    progress = DealProgress.new(@quote.reload).call
    assert_equal "draft", progress.stage
    assert_equal "choose_delivery", progress.action_key

    delivery = @version.version_deliveries.create!(company: @company, quote: @quote, created_by: @user,
      channel: "external", external_channel: "whatsapp", recipient: "Anna", status: "externally_sent",
      delivered_at: Time.current, idempotency_key: SecureRandom.uuid)
    @quote.update!(status: "sent", sent_at: delivery.delivered_at)

    progress = DealProgress.new(@quote.reload).call
    assert_equal "live", progress.stage
    assert_equal "wait", progress.action_key
    assert_equal "View status unavailable", delivery.view_status_label
  end

  test "seller can record immutable email acceptance and close without PI" do
    @version.version_deliveries.create!(company: @company, quote: @quote, created_by: @user,
      channel: "pdf_download", recipient: "buyer@example.com", delivered_at: Time.current,
      idempotency_key: SecureRandom.uuid)
    acceptance = ExternalAcceptanceRecorder.new(revision: @version, actor: @user,
      attributes: { acceptance_method: "email_confirmation", name: "Anna Buyer", email: "anna@example.com",
        accepted_at: Time.current, evidence_summary: "Email thread 8842" }, idempotency_key: "email-8842").call

    @quote.update!(shipping_amount: 999)
    assert_not_equal @quote.grand_total.to_d, acceptance.total.to_d
    progress = DealProgress.new(@quote.reload).call
    assert_equal "accepted", progress.stage
    assert_equal "close_won", progress.action_key
  end

  test "workspace requirements determine accepted next action" do
    ExternalAcceptanceRecorder.new(revision: @version, actor: @user,
      attributes: { acceptance_method: "verbal", name: "Anna Buyer", accepted_at: Time.current,
        note: "Confirmed by phone" }, idempotency_key: "phone-1").call
    @company.update!(require_final_document: true)
    assert_equal "generate_final_document", DealProgress.new(@quote.reload).call.action_key
  end

  test "PO comparison distinguishes exact and material differences" do
    exact = DealResponse.new(company: @company, quote: @quote, quote_revision: @version, kind: "purchase_order",
      source: "purchase_order", body: "PO total: USD #{@version.total}", received_at: Time.current,
      idempotency_key: "po-exact")
    material = exact.dup
    material.body = "PO total: USD 1"
    material.idempotency_key = "po-material"

    assert_equal "exact_match", DealResponseAnalyzer.new(exact).call["severity"]
    assert_equal "material_difference", DealResponseAnalyzer.new(material).call["severity"]
  end

  test "duplicate publish with unchanged content returns same version" do
    current_snapshot = QuoteSnapshotBuilder.new(@quote.reload).as_json
    assert_empty SnapshotDiff.new(@version.snapshot, current_snapshot).call
    duplicate = RevisionPublisher.new(quote: @quote.reload, actor: @user).call.revision
    assert_equal @version.id, duplicate.id
    assert_equal 1, @quote.quote_revisions.count
  end


  test "published version content and exported workbook remain immutable" do
    original_snapshot = @version.snapshot.deep_dup
    original_total = @version.total
    first_export = PublishedVersionFileGenerator.new(@version).excel

    @version.total = original_total + 100
    assert_not @version.save
    assert_match "immutable", @version.errors.full_messages.join.downcase
    @version.reload
    assert_raises ActiveRecord::StatementInvalid do
      @version.transaction(requires_new: true) { @version.update_columns(total: original_total + 100) }
    end

    @quote.update!(status: "draft", shipping_amount: 725)
    second = RevisionPublisher.new(quote: @quote, actor: @user).call.revision
    assert_equal 2, second.number
    assert_equal original_snapshot, @version.reload.snapshot
    assert_equal original_total, @version.total
    second_export = PublishedVersionFileGenerator.new(@version).excel
    first_blob = ActiveStorage::Blob.create_and_upload!(io: first_export.io, filename: first_export.filename, content_type: first_export.content_type)
    second_blob = ActiveStorage::Blob.create_and_upload!(io: second_export.io, filename: second_export.filename, content_type: second_export.content_type)
    first_parsed = PublishedWorkbookParser.new(first_blob).call
    second_parsed = PublishedWorkbookParser.new(second_blob).call
    assert_equal first_parsed.metadata, second_parsed.metadata
    assert_equal first_parsed.items, second_parsed.items
  end

  test "system link and email execution determine delivery result" do
    ActionMailer::Base.deliveries.clear
    link = @version.version_deliveries.create!(company: @company, quote: @quote, created_by: @user,
      channel: "buyer_room_link", recipient: "buyer@example.com", subject: "Version",
      status: "draft", idempotency_key: SecureRandom.uuid)
    VersionDeliveryExecutor.new(link).call
    assert_equal "sent", link.reload.status

    email = @version.version_deliveries.create!(company: @company, quote: @quote, created_by: @user,
      channel: "email_link", recipient: "buyer@example.com", subject: "Version",
      message_body: "Review this Version", status: "draft", idempotency_key: SecureRandom.uuid)
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      VersionDeliveryExecutor.new(email).call
    end
    assert_equal "sent", email.reload.status
    assert_equal @version.id.to_s, ActionMailer::Base.deliveries.last["X-Rubusoo-Version"].value
  end

  test "returned workbook differences apply only selected values to working draft" do
    require "axlsx"
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Published quote") do |sheet|
      sheet.add_row [ "Rubusoo Published Version" ]
      sheet.add_row [ "Deal ID", @quote.id, "Version ID", @version.id ]
      sheet.add_row [ "Buyer", @quote.customer.name, "Currency", "USD" ]
      sheet.add_row []
      sheet.add_row %w[Item SKU Description Specifications Quantity Unit Unit_price Discount Amount]
      item = @quote.quote_items.first
      sheet.add_row [ 1, item.sku_snapshot, item.description, "Voltage: 400V", 9, "set", 525, 0, 4725 ]
      sheet.add_row []
      sheet.add_row [ "Shipping", 350 ]
      sheet.add_row [ "Total", 5075 ]
    end
    package.workbook.add_worksheet(name: "Rubusoo metadata") do |sheet|
      sheet.add_row [ "deal_id", @quote.id ]; sheet.add_row [ "version_id", @version.id ]
      canonical = lambda do |value|
        if value.is_a?(Hash)
          value.keys.sort.to_h { |key| [ key, canonical.call(value[key]) ] }
        elsif value.is_a?(Array)
          value.map { |entry| canonical.call(entry) }
        else
          value
        end
      end
      sheet.add_row [ "secure_fingerprint", Digest::SHA256.hexdigest(canonical.call(@version.snapshot).to_json) ]
    end
    response = @quote.deal_responses.new(company: @company, quote_revision: @version, recorded_by: @user,
      kind: "returned_excel", source: "excel", received_at: Time.current, idempotency_key: SecureRandom.uuid)
    response.attachment.attach(io: StringIO.new(package.to_stream.read), filename: "buyer-returned.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    response.save!
    review = ReturnedVersionComparator.new(response).call
    response.update!(difference_review: review)

    assert review["source_valid"]
    assert_includes review["changes"].pluck("path"), "items.0.quantity"
    assert_includes review["changes"].pluck("path"), "items.0.unit_price"
    WorkingUpdateApplier.new(response:, selected_paths: %w[items.0.quantity items.0.unit_price]).call
    assert_equal 9, @quote.quote_items.first.reload.quantity
    assert_equal 525.to_d, @quote.quote_items.first.unit_price
    assert_equal "applied", response.reload.status
  end
end
