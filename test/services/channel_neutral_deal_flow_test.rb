require "test_helper"

class ChannelNeutralDealFlowTest < ActiveSupport::TestCase
  setup do
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
      channel: "external", external_channel: "whatsapp", recipient: "Anna", status: "succeeded",
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
end
