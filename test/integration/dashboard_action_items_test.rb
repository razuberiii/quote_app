require "test_helper"

class DashboardActionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "quote todo includes actionable quote signals" do
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

    assert_select "#quote-todo-section", text: /QT-RADAR-DEDUP/
  end

  test "quote todo only shows actionable and in-progress quotes" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "Todo Customer",
      status: "new",
      customer_level: "normal"
    )

    won_missing = Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-TODO-WON-MISSING",
      revision_number: 1,
      currency: "USD",
      status: "won",
      win_reason: "price_accepted",
      win_reason_detail: "seed",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Won missing", unit_price: 100, quantity: 1 } ]
    )
    won_missing.update_columns(win_reason: nil, win_reason_detail: nil)

    lost_missing = Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-TODO-LOST-MISSING",
      revision_number: 1,
      currency: "USD",
      status: "lost",
      loss_reason: "competitor_selected",
      loss_reason_detail: "seed",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Lost missing", unit_price: 100, quantity: 1 } ]
    )
    lost_missing.update_columns(loss_reason: nil, loss_reason_detail: nil)

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-TODO-DRAFT",
      revision_number: 1,
      currency: "USD",
      status: "draft",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Draft quote", unit_price: 100, quantity: 1 } ]
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-TODO-COMPLETE",
      revision_number: 1,
      currency: "USD",
      status: "won",
      issued_on: Date.current,
      win_reason: "price_accepted",
      win_reason_detail: "accepted by customer",
      quote_items_attributes: [ { description: "Complete quote", unit_price: 100, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#quote-todo-section", text: /QT-TODO-WON-MISSING/
    assert_select "#quote-todo-section", text: /QT-TODO-LOST-MISSING/
    assert_select "#quote-todo-section", text: /QT-TODO-DRAFT/
    assert_select "#quote-todo-section", text: /QT-TODO-COMPLETE/, count: 0
  end

  test "today focus keeps one card per customer when multiple reasons match" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "Multi Reason Co",
      status: "new",
      customer_level: "normal",
      next_follow_up_date: Date.current - 2.days,
      last_follow_up_date: Date.current - 30.days
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-MULTI-FOCUS",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 20.days.ago,
      issued_on: Date.current - 25.days,
      updated_at: 20.days.ago,
      quote_items_attributes: [ { description: "High value item", unit_price: 10_000, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#today-focus-section .dashboard-action-item strong", text: /Multi Reason Co/, count: 1
  end

  test "quote todo keeps strong action and hides related weak reminders for quote risk customer" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "Absorb Risk Co",
      status: "new",
      customer_level: "normal"
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-ABSORB-EXPIRING",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      valid_until: Date.current + 2.days,
      issued_on: Date.current - 8.days,
      quote_items_attributes: [ { description: "Expiring quote", unit_price: 300, quantity: 1 } ]
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-ABSORB-NOTVIEWED",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      issued_on: Date.current - 8.days,
      quote_items_attributes: [ { description: "No view quote", unit_price: 200, quantity: 1 } ]
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-ABSORB-DRAFT",
      revision_number: 1,
      currency: "USD",
      status: "draft",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Draft quote", unit_price: 100, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#quote-todo-section", text: /QT-ABSORB-DRAFT/
    assert_select "#quote-todo-section", text: /QT-ABSORB-EXPIRING/, count: 0
    assert_select "#quote-todo-section", text: /QT-ABSORB-NOTVIEWED/, count: 0
  end

  test "quote todo does not hide unrelated weak reminders" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "Unrelated Risk Co",
      status: "new",
      customer_level: "normal"
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-UNRELATED-STALL",
      revision_number: 1,
      currency: "USD",
      status: "negotiating",
      issued_on: Date.current - 10.days,
      updated_at: 10.days.ago,
      quote_items_attributes: [ { description: "Stalled quote", unit_price: 500, quantity: 1 } ]
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-UNRELATED-NOTVIEWED",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      issued_on: Date.current - 8.days,
      quote_items_attributes: [ { description: "Not viewed quote", unit_price: 200, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#quote-todo-section", text: /QT-UNRELATED-NOTVIEWED/
  end

  test "quote todo excludes pi documents from actionable list" do
    company = @user.company
    customer = Customer.create!(
      company: company,
      name: "PI Filter Co",
      status: "new",
      customer_level: "normal"
    )

    source_quote = Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-PI-SOURCE",
      revision_number: 1,
      currency: "USD",
      status: "sent",
      sent_at: 8.days.ago,
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Source quote", unit_price: 100, quantity: 1 } ]
    )

    Quote.create!(
      company: company,
      customer: customer,
      template: source_quote.template,
      source_quote: source_quote,
      quote_no: "QT-PI-DOC",
      revision_number: 1,
      currency: "USD",
      status: "draft",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "PI document", unit_price: 100, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#quote-todo-section", text: /QT-PI-SOURCE/
    assert_select "#quote-todo-section", text: /QT-PI-DOC/, count: 0
  end

  test "dashboard modules hide customer and quotes owned by other user when owner mode enabled" do
    skip "internal owner feature disabled" unless Customer.internal_owner_enabled?

    company = @user.company
    teammate = User.create!(
      email: "teammate_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      company: company,
      company_role: :member,
      role: :user,
      email_verified_at: Time.current
    )

    customer = Customer.create!(
      company: company,
      name: "Other Owner Customer",
      status: "new",
      customer_level: "normal",
      internal_owner_id: teammate.id,
      next_follow_up_date: Date.current - 1.day
    )

    Quote.create!(
      company: company,
      customer: customer,
      quote_no: "QT-OTHER-OWNER-DRAFT",
      revision_number: 1,
      currency: "USD",
      status: "draft",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Owner draft", unit_price: 120, quantity: 1 } ]
    )

    get dashboard_path(locale: :"zh-CN")
    assert_response :success

    assert_select "#today-focus-section", text: /Other Owner Customer/, count: 0
    assert_select "#quote-todo-section", text: /QT-OTHER-OWNER-DRAFT/, count: 0
  end
end
