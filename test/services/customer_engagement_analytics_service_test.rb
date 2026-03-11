require "test_helper"

class CustomerEngagementAnalyticsServiceTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:one)
  end

  test "view_hour_distribution returns empty hash when no view events" do
    dist = CustomerEngagementAnalyticsService.new(@customer).view_hour_distribution
    assert_empty dist
  end

  test "best_contact_time returns nil when no view data" do
    result = CustomerEngagementAnalyticsService.new(@customer).best_contact_time
    assert_nil result
  end

  test "best_contact_time returns a formatted time range string when views exist" do
    quote      = make_quote
    share      = make_share(quote)
    # Create two view events at 14:xx (peak hour)
    make_view(share, at: Time.current.change(hour: 14))
    make_view(share, at: Time.current.change(hour: 14))
    make_view(share, at: Time.current.change(hour: 9))

    result = CustomerEngagementAnalyticsService.new(@customer).best_contact_time

    assert_not_nil result
    assert_match(/\d{1,2}:\d{2}/, result, "Expected a time range string like '14:00–16:00'")
  end

  test "summary contains best_time and total_views keys" do
    result = CustomerEngagementAnalyticsService.new(@customer).summary

    assert result.key?(:best_time)
    assert result.key?(:total_views)
  end

  test "summary total_views is 0 when no events" do
    result = CustomerEngagementAnalyticsService.new(@customer).summary
    assert_equal 0, result[:total_views]
  end

  private

  def make_quote
    Quote.create!(
      company:         @customer.company,
      customer:        @customer,
      quote_no:        "QT-ENGAGE-#{SecureRandom.hex(4).upcase}",
      revision_number: 1,
      currency:        "USD",
      issued_on:       Date.current,
      status:          "sent",
      quote_items_attributes: [ { description: "Item", unit_price: 100, quantity: 1 } ]
    )
  end

  def make_share(quote)
    QuoteShare.create!(
      quote:     quote,
      company:   quote.company,
      token:     SecureRandom.urlsafe_base64(16),
      expires_at: 30.days.from_now,
      snapshot:  { title: "Test Quote" }
    )
  end

  def make_view(share, at: Time.current)
    QuoteViewEvent.create!(
      quote_share:  share,
      duration_ms:  1000,
      created_at:   at,
      updated_at:   at
    )
  end
end
