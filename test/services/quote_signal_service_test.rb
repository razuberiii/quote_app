require "test_helper"

class QuoteSignalServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    @customer = customers(:one)
    @customer.update!(last_follow_up_date: 5.days.ago.to_date)
  end

  test "returns revision_requested as highest priority" do
    quote = build_quote(status: "negotiating", changes_requested_at: 1.day.ago, valid_until: Date.current + 1.day)

    signal = QuoteSignalService.new(quote).call

    assert_equal "revision_requested", signal.type
    assert_equal "urgent", signal.priority
    assert_equal "prepare_revision", signal.recommended_action
  end

  test "returns expiring_soon for open quote expiring in 3 days" do
    quote = build_quote(status: "sent", valid_until: Date.current + 2.days, sent_at: 4.days.ago)

    signal = QuoteSignalService.new(quote).call

    assert_equal "expiring_soon", signal.type
    assert_equal "renew_quote", signal.recommended_action
  end

  test "does not return expiring_soon for won quote" do
    quote = build_quote(status: "won", valid_until: Date.current + 2.days, sent_at: 4.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "expiring_soon", signal.type
  end

  test "does not return expiring_soon for lost quote" do
    quote = build_quote(status: "lost", valid_until: Date.current + 2.days, sent_at: 4.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "expiring_soon", signal.type
  end

  test "does not return expiring_soon for expired quote" do
    quote = build_quote(status: "expired", valid_until: Date.current + 2.days, sent_at: 4.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "expiring_soon", signal.type
  end

  test "does not return expiring_soon for draft quote" do
    quote = build_quote(status: "draft", valid_until: Date.current + 2.days, sent_at: 4.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "expiring_soon", signal.type
  end

  test "returns not_viewed_7d when quote remains unviewed" do
    quote = build_quote(status: "sent", sent_at: 8.days.ago)

    signal = QuoteSignalService.new(quote).call

    assert_equal "not_viewed_7d", signal.type
    assert_equal "risk", signal.priority
  end

  test "does not return not_viewed_7d for won quote" do
    quote = build_quote(status: "won", sent_at: 8.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "not_viewed_7d", signal.type
    refute_equal "resend_reminder", signal.recommended_action
  end

  test "does not return not_viewed_7d for lost quote" do
    quote = build_quote(status: "lost", sent_at: 8.days.ago)

    signal = QuoteSignalService.new(quote).call

    refute_equal "not_viewed_7d", signal.type
    refute_equal "resend_reminder", signal.recommended_action
  end

  private

  def build_quote(status:, sent_at: nil, valid_until: nil, changes_requested_at: nil)
    attrs = {
      company: @company,
      customer: @customer,
      quote_no: "QT-SIGNAL-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency: "USD",
      status: status,
      sent_at: sent_at,
      valid_until: valid_until,
      changes_requested_at: changes_requested_at,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Signal Item",
          unit_price: 100,
          quantity: 1
        }
      ]
    }

    attrs[:win_reason] = "price_accepted" if status.to_s == "won"
    attrs[:loss_reason] = "price_too_high" if status.to_s == "lost"

    Quote.create!(
      **attrs
    )
  end
end
