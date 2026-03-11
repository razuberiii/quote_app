require "test_helper"

class ChannelUsageAnalyticsServiceTest < ActiveSupport::TestCase
  setup do
    @company  = companies(:one)
    @customer = customers(:one)
    @user     = users(:one)
  end

  test "channel_distribution returns empty hash when no events" do
    dist = ChannelUsageAnalyticsService.new(company: @company).channel_distribution
    assert_empty dist
  end

  test "channel_distribution counts events grouped by channel" do
    make_event("whatsapp")
    make_event("whatsapp")
    make_event("email")

    dist = ChannelUsageAnalyticsService.new(company: @company).channel_distribution

    assert_equal 2, dist["whatsapp"]
    assert_equal 1, dist["email"]
  end

  test "channel_distribution is sorted descending by count" do
    make_event("email")
    make_event("whatsapp")
    make_event("whatsapp")

    dist = ChannelUsageAnalyticsService.new(company: @company).channel_distribution

    assert_equal "whatsapp", dist.keys.first
  end

  test "summary returns array with channel, total, and reply_rate placeholder" do
    make_event("whatsapp")
    make_event("email")

    result = ChannelUsageAnalyticsService.new(company: @company).summary

    assert_kind_of Array, result
    assert result.all? { |r| r.key?(:channel) && r.key?(:total) && r.key?(:reply_rate) }
    whatsapp_row = result.find { |r| r[:channel] == "whatsapp" }
    assert_equal 1, whatsapp_row[:total]
    assert_nil whatsapp_row[:reply_rate]
  end

  test "channel_distribution is scoped to company" do
    other_company  = companies(:two)
    other_customer = customers(:two)
    other_user     = users(:two)
    make_event("email", customer: other_customer, user: other_user)
    make_event("whatsapp")

    dist = ChannelUsageAnalyticsService.new(company: @company).channel_distribution

    assert_equal 1, dist.values.sum
    assert dist.key?("whatsapp")
  end

  private

  def make_event(channel, customer: @customer, user: @user)
    CustomerFollowUpEvent.create!(
      customer:     customer,
      user:         user,
      channel:      channel,
      contacted_at: Time.current
    )
  end
end
