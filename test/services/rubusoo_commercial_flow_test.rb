require "test_helper"

class RubusooCommercialFlowTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    @company.update!(plan: "pro", subscription_status: "active", trial_ends_at: 10.days.from_now)
    @user = users(:one)
    @quote = quotes(:one)
    @quote.update!(status: "draft", valid_until: 30.days.from_now,
      trade_term: "CIF Hamburg", payment_term: "30% deposit, 70% before shipment",
      shipping_amount: 350, shipping_price_source: "freight_forwarder_quote")
  end

  test "publishing creates immutable current revision and supersedes previous" do
    first = RevisionPublisher.new(quote: @quote, actor: @user).call.revision
    @quote.update!(status: "draft", shipping_amount: 25)
    second = RevisionPublisher.new(quote: @quote, actor: @user).call.revision

    assert_equal 1, first.reload.number
    assert_equal "superseded", first.status
    assert_not first.actionable?
    assert_equal 2, second.number
    assert second.actionable?
    assert_equal 25.to_d, second.snapshot["shipping_amount"].to_d
  end

  test "accept is idempotent and locks revision snapshot" do
    revision = RevisionPublisher.new(quote: @quote, actor: @user).call.revision
    key = SecureRandom.uuid
    attributes = { name: "A Buyer", email: "buyer@example.com" }
    first = QuoteAcceptor.new(revision: revision, attributes: attributes, selection: { "plan" => "recommended" }, idempotency_key: key).call
    second = QuoteAcceptor.new(revision: revision.reload, attributes: attributes, selection: {}, idempotency_key: key).call

    assert_equal first.id, second.id
    assert_equal "recommended", first.snapshot.dig("buyer_selection", "plan")
    assert_equal 1, QuoteAcceptance.where(quote: @quote).count
  end

  test "PI generation is idempotent and isolated by workspace" do
    revision = RevisionPublisher.new(quote: @quote, actor: @user).call.revision
    acceptance = QuoteAcceptor.new(revision: revision, attributes: { name: "A Buyer", email: "buyer@example.com" }, selection: {}, idempotency_key: "accept-1").call
    first = ProformaInvoiceGenerator.new(acceptance: acceptance, actor: @user).call
    second = ProformaInvoiceGenerator.new(acceptance: acceptance.reload, actor: @user).call

    assert_equal first.id, second.id
    assert_equal acceptance.snapshot, first.snapshot
    assert_raises(ActiveRecord::RecordNotFound) do
      ProformaInvoiceGenerator.new(acceptance: acceptance, actor: users(:two)).call
    end
  end

  test "trial send limit is enforced server side" do
    @company.update!(plan: "trial", subscription_status: "trialing", trial_ends_at: 5.days.from_now)
    5.times do |number|
      @company.quote_revisions.create!(quote: @quote, number: number + 1, status: "superseded", currency: "USD", total: 1,
        snapshot: {}, secure_token: SecureRandom.urlsafe_base64(32), sent_at: Time.current)
    end
    assert_not @company.can_send_quote?
  end
end
