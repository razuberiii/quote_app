require "test_helper"

class DealOutcomeAnalyticsServiceTest < ActiveSupport::TestCase
  setup do
    @company  = companies(:one)
    @customer = customers(:one)
  end

  test "win_reason_distribution counts won quotes grouped by win_reason" do
    make_won("price_accepted")
    make_won("price_accepted")
    make_won("buyer_relationship")

    dist = DealOutcomeAnalyticsService.new(company: @company).win_reason_distribution

    assert_equal 2, dist["price_accepted"]
    assert_equal 1, dist["buyer_relationship"]
  end

  test "loss_reason_distribution counts lost quotes grouped by loss_reason" do
    make_lost("price_too_high")
    make_lost("price_too_high")
    make_lost("other")

    dist = DealOutcomeAnalyticsService.new(company: @company).loss_reason_distribution

    assert_equal 2, dist["price_too_high"]
    assert_equal 1, dist["other"]
  end

  test "loss_other_breakdown groups normalized free-text details" do
    make_lost("other", detail: "Too slow delivery")
    make_lost("other", detail: "too slow delivery ")
    make_lost("other", detail: "competitor price")

    breakdown = DealOutcomeAnalyticsService.new(company: @company).loss_other_breakdown

    assert_equal 2, breakdown["too slow delivery"]
    assert_equal 1, breakdown["competitor price"]
  end

  test "summary returns view-ready arrays with pct fields" do
    make_won("price_accepted")
    make_won("buyer_relationship")
    make_lost("price_too_high")

    result = DealOutcomeAnalyticsService.new(company: @company).summary

    assert result.key?(:win_reasons)
    assert result.key?(:loss_reasons)
    assert result.key?(:loss_other_details)

    label = I18n.t("analytics.reason_labels.win.price_accepted")
    win_row = result[:win_reasons].find { |r| r[:label] == label }
    assert_not_nil win_row
    assert_equal 50, win_row[:pct]
    assert_equal 1,  win_row[:count]
  end

  test "summary win_reasons are empty when no won quotes exist" do
    result = DealOutcomeAnalyticsService.new(company: @company).summary
    assert_empty result[:win_reasons]
  end

  test "summary includes unspecified bucket when reason is missing" do
    quote = make_won("price_accepted")
    quote.update_columns(win_reason: nil, win_reason_detail: nil)

    result = DealOutcomeAnalyticsService.new(company: @company).summary
    unspecified = result[:win_reasons].find { |r| r[:label] == I18n.t("analytics.reason_labels.win.unspecified") }

    assert_not_nil unspecified
    assert_equal 1, unspecified[:count]
  end

  test "summary is scoped to company — does not bleed into other companies" do
    other_company  = companies(:two)
    other_customer = customers(:two)
    make_quote(company: other_company, customer: other_customer, status: "won", win_reason: "price_accepted")
    make_won("buyer_relationship")

    result = DealOutcomeAnalyticsService.new(company: @company).summary

    assert_equal 1, result[:win_reasons].sum { |r| r[:count] }
    assert_equal I18n.t("analytics.reason_labels.win.buyer_relationship"), result[:win_reasons].first[:label]
  end

  test "summary excludes pi documents" do
    source = make_won("price_accepted")
    Quote.create!(
      company: @company,
      customer: @customer,
      template: source.template,
      source_quote: source,
      quote_no: "QT-OUTCOME-PI-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency: "USD",
      issued_on: Date.current,
      status: "won",
      win_reason: "buyer_relationship",
      win_reason_detail: "pi should be excluded",
      quote_items_attributes: [ { description: "PI line", unit_price: 100, quantity: 1 } ]
    )

    result = DealOutcomeAnalyticsService.new(company: @company).summary

    assert_equal 1, result[:win_reasons].sum { |row| row[:count] }
    assert_equal I18n.t("analytics.reason_labels.win.price_accepted"), result[:win_reasons].first[:label]
  end

  private

  def make_won(win_reason, detail: "good deal")
    make_quote(status: "won", win_reason: win_reason, win_reason_detail: detail)
  end

  def make_lost(loss_reason, detail: "not right")
    make_quote(status: "lost", loss_reason: loss_reason, loss_reason_detail: detail)
  end

  def make_quote(company: @company, customer: @customer, **attrs)
    Quote.create!(
      company:         company,
      customer:        customer,
      quote_no:        "QT-OUTCOME-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency:        "USD",
      issued_on:       Date.current,
      quote_items_attributes: [ { description: "Item", unit_price: 100, quantity: 1 } ],
      **attrs
    )
  end
end
