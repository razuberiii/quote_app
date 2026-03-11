require_relative "application_system_test_case"

class DashboardDealRadarTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @company = @user.company
  end

  test "deal radar sorts by priority and preserves locale in ctas" do
    old_customer = Customer.create!(company: @company, name: "Dragon Labs", status: "new", customer_level: "normal", last_follow_up_date: 6.days.ago.to_date)

    revision_quote = create_quote_for_radar(old_customer, quote_no: "QT-RADAR-1", status: "negotiating", changes_requested_at: 1.day.ago, valid_until: Date.current + 2.days)
    risk_quote = create_quote_for_radar(old_customer, quote_no: "QT-RADAR-2", status: "sent", sent_at: 8.days.ago)
    watch_quote = create_quote_for_radar(old_customer, quote_no: "QT-RADAR-3", status: "sent", sent_at: 4.days.ago)

    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    visit dashboard_path(locale: :"zh-CN")

    radar = page.first(".dashboard-action-list")
    titles = radar.all(".dashboard-action-item strong", minimum: 3).first(3).map(&:text)

    assert_equal QuoteSignalService.new(revision_quote).call.type, "revision_requested"
    assert_equal [
      QuoteSignalPresenter.new(locale: :"zh-CN").quote_title(revision_quote),
      QuoteSignalPresenter.new(locale: :"zh-CN").quote_title(risk_quote),
      QuoteSignalPresenter.new(locale: :"zh-CN").quote_title(watch_quote)
    ], titles

    assert_includes page.html, "locale=zh-CN"
  end

  private

  def create_quote_for_radar(customer, quote_no:, status:, sent_at: nil, changes_requested_at: nil, valid_until: nil)
    Quote.create!(
      company: @company,
      customer: customer,
      quote_no: quote_no,
      revision_number: 1,
      currency: "USD",
      status: status,
      sent_at: sent_at,
      changes_requested_at: changes_requested_at,
      valid_until: valid_until,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: quote_no,
          unit_price: 120,
          quantity: 1
        }
      ]
    )
  end
end
