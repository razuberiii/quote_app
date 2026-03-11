require "test_helper"

class DashboardActionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "deal radar quote signal is not duplicated in today focus" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "Radar Customer",
      status: "new",
      customer_level: "normal"
    )

    quote = Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-RADAR-DEDUP",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      issued_on: Date.current,
      quote_items_attributes: [
        {
          description: "Radar item",
          unit_price: 50,
          quantity: 1
        }
      ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#deal-radar-section", text: /QT-RADAR-DEDUP/
    assert_select "#today-focus-section", text: /QT-RADAR-DEDUP/, count: 0
  end

  test "action items count matches rendered items and hidden list count" do
    company = @user.company

    5.times do |index|
      customer = Customer.create!(
        company: company,
        name: "Action Customer #{index}",
        status: "new",
        customer_level: "normal"
      )

      Quote.create!(
        company: company,
        customer: customer,
        quote_no: "QT-COUNT-#{index}",
        revision_number: 1,
        currency: "USD",
        status: "sent",
        sent_at: 8.days.ago,
        issued_on: Date.current,
        quote_items_attributes: [
          {
            description: "Action item #{index}",
            unit_price: 50,
            quantity: 1
          }
        ]
      )
    end

    expected_count = ActionItemGenerator.new(user: @user).call.count

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#action-items-section .dashboard-alert-pill", text: /#{expected_count}/
    assert_select "#action-items-section .dashboard-task-item", count: expected_count

    hidden_count = [ expected_count - 4, 0 ].max
    assert_select "#action-items-section [data-action-items-more] .dashboard-task-item", count: hidden_count
    assert_select "#action-items-section [data-action-items-toggle]", text: /#{hidden_count}/ if hidden_count.positive?
  end
end
