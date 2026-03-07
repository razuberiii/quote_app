require "test_helper"

class QuoteFunnelReportServiceTest < ActiveSupport::TestCase
  test "counts quote funnel metrics from latest quote threads" do
    company = companies(:one)
    customer = customers(:one)

    sent_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-FUNNEL-001",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 2.days.ago,
      issued_on: Date.current
    )
    sent_quote.quote_items.build(description: "Widget A", quantity: 1, unit_price: 10)
    sent_quote.save!

    accepted_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-FUNNEL-002",
      revision_number: 1,
      currency: "USD",
      status: "won",
      sent_at: 3.days.ago,
      viewed_at: 2.days.ago,
      accepted_at: 1.day.ago,
      final_amount: 15,
      win_reason: "price_accepted",
      issued_on: Date.current
    )
    accepted_quote.quote_items.build(description: "Widget B", quantity: 1, unit_price: 15)
    accepted_quote.save!

    revision_v1 = company.quotes.new(
      customer: customer,
      quote_no: "QT-FUNNEL-003",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 6.days.ago,
      issued_on: Date.current
    )
    revision_v1.quote_items.build(description: "Widget C", quantity: 1, unit_price: 11)
    revision_v1.save!

    revision_v2 = company.quotes.new(
      customer: customer,
      quote_no: "QT-FUNNEL-003",
      revision_number: 2,
      currency: "USD",
      status: "negotiating",
      sent_at: 5.days.ago,
      viewed_at: 4.days.ago,
      changes_requested_at: 4.days.ago,
      issued_on: Date.current
    )
    revision_v2.quote_items.build(description: "Widget C", quantity: 2, unit_price: 12)
    revision_v2.save!

    lost_quote = company.quotes.new(
      customer: customer,
      quote_no: "QT-FUNNEL-004",
      revision_number: 1,
      currency: "USD",
      status: "lost",
      sent_at: 4.days.ago,
      viewed_at: 3.days.ago,
      loss_reason: "competitor_selected",
      issued_on: Date.current
    )
    lost_quote.quote_items.build(description: "Widget D", quantity: 1, unit_price: 9)
    lost_quote.save!

    report = QuoteFunnelReportService.new(company: company).call

    assert_equal 4, report[:quotes_sent]
    assert_equal 3, report[:quotes_viewed]
    assert_equal 1, report[:revisions_requested]
    assert_equal 1, report[:quotes_accepted]
    assert_equal 1, report[:quotes_lost]
  end
end
