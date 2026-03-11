require "test_helper"

class RevisionDepthAnalyticsServiceTest < ActiveSupport::TestCase
  setup do
    @company  = Company.create!(name: "RevDepth Test Co #{SecureRandom.hex(4)}")
    @customer = Customer.create!(
      company:      @company,
      name:         "Test Buyer",
      country:      "US",
      contact_name: "Buyer",
      email:        "buyer+#{SecureRandom.hex(4)}@example.com",
      status:       "active"
    )
  end

  test "win_rate_by_revision returns empty array when no closed quotes" do
    result = RevisionDepthAnalyticsService.new(company: @company).win_rate_by_revision
    assert_empty result
  end

  test "win_rate_by_revision groups won/lost by revision_number" do
    make_quote(quote_no: "QT-ALPHA", status: "won")
    make_quote(quote_no: "QT-BETA",  status: "lost")
    make_quote(quote_no: "QT-ALPHA", status: "won")

    result = RevisionDepthAnalyticsService.new(company: @company).win_rate_by_revision

    rev1 = result.find { |r| r[:revision_number] == 1 }
    rev2 = result.find { |r| r[:revision_number] == 2 }

    assert_not_nil rev1
    assert_equal 2, rev1[:total]
    assert_equal 1, rev1[:wins]
    assert_equal 50, rev1[:win_rate]

    assert_not_nil rev2
    assert_equal 1, rev2[:total]
    assert_equal 1, rev2[:wins]
    assert_equal 100, rev2[:win_rate]
  end

  test "win_rate_by_revision excludes open/draft quotes" do
    make_quote(quote_no: "QT-EXCL-A", status: "sent")
    make_quote(quote_no: "QT-EXCL-B", status: "won")

    result = RevisionDepthAnalyticsService.new(company: @company).win_rate_by_revision

    rev1 = result.find { |r| r[:revision_number] == 1 }
    assert_equal 1, rev1[:total]
  end

  test "win_rate_by_revision counts all closed revisions per quote family" do
    make_quote(quote_no: "QT-FAM", status: "lost")
    make_quote(quote_no: "QT-FAM", status: "won")

    result = RevisionDepthAnalyticsService.new(company: @company).win_rate_by_revision

    assert_equal 2, result.sum { |r| r[:total] }
    rev1 = result.find { |r| r[:revision_number] == 1 }
    rev2 = result.find { |r| r[:revision_number] == 2 }
    assert_equal 1, rev1[:total]
    assert_equal 0, rev1[:wins]
    assert_equal 1, rev2[:total]
    assert_equal 1, rev2[:wins]
  end

  test "revision_depth_distribution counts all quotes regardless of status" do
    make_quote(quote_no: "QT-DIST-A", status: "sent")   # rev=1 auto
    make_quote(quote_no: "QT-DIST-B", status: "won")    # rev=1 auto
    make_quote(quote_no: "QT-DIST-A", status: "draft")  # rev=2 auto (same family)

    dist = RevisionDepthAnalyticsService.new(company: @company).revision_depth_distribution

    assert_equal 2, dist[1]
    assert_equal 1, dist[2]
  end

  test "results are scoped to company" do
    other_company  = Company.create!(name: "Other Co #{SecureRandom.hex(4)}")
    other_customer = Customer.create!(
      company:      other_company,
      name:         "Other Buyer",
      country:      "US",
      contact_name: "Buyer",
      email:        "other+#{SecureRandom.hex(4)}@example.com",
      status:       "active"
    )
    make_quote(quote_no: "QT-OTHER-CO", status: "won",
               company: other_company, customer: other_customer)
    make_quote(quote_no: "QT-MINE", status: "lost")
    make_quote(quote_no: "QT-MINE", status: "won")

    result = RevisionDepthAnalyticsService.new(company: @company).win_rate_by_revision

    assert_equal 2, result.sum { |r| r[:total] }, "Expected only @company closed deals"
    assert_equal [ 1, 2 ], result.map { |r| r[:revision_number] }
  end

  private

  def make_quote(company: @company, customer: @customer, quote_no: nil, **attrs)
    defaults = {
      company:    company,
      customer:   customer,
      quote_no:   quote_no || "QT-DEPTH-#{SecureRandom.hex(4).upcase}",
      currency:   "USD",
      issued_on:  Date.current,
      quote_items_attributes: [ { description: "Item", unit_price: 100, quantity: 1 } ]
    }
    effective_status = attrs[:status]
    defaults[:win_reason]        = "other" if effective_status == "won"
    defaults[:win_reason_detail] = "test"  if effective_status == "won"
    defaults[:loss_reason]       = "other" if effective_status == "lost"
    defaults[:loss_reason_detail] = "test" if effective_status == "lost"

    Quote.create!(**defaults.merge(attrs))
  end
end
