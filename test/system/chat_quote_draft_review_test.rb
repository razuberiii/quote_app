require_relative "application_system_test_case"
require "fileutils"
require "selenium/webdriver"

if ENV["CHROMEDRIVER_PATH"].present?
  Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"]
end

class ChatQuoteDraftReviewTest < ApplicationSystemTestCase
  driven_by :selenium,
    using: :headless_chrome,
    screen_size: [ 1440, 1800 ],
    options: { browser: :chrome, timeout: 120 }

  OUTPUT_ROOT = Rails.root.join("tmp", "review_shots", "chat_quote_draft_20260805")

  test "seller reviews a recommended chat-derived quote draft on desktop and mobile" do
    product = products(:one)
    product.update!(price_currency: "USD", default_price: 480, unit: "set", moq: 2,
      lead_time: "20 days", default_specs: [ { name: "Voltage", value: "380V" }, { name: "Protection", value: "IP54" } ])
    inquiry = companies(:one).inquiries.create!(created_by: users(:one), source_type: "chat", status: "review",
      source_text: "Please quote 5 HZ-240 units, 380V/50Hz, CIF Hamburg in USD.",
      extracted_data: {
        "customer" => "Atlas Industrial", "currency" => "USD",
        "products" => [ { "name" => "Hydraulic Pump", "model" => "HZ-240", "quantity" => 5,
          "unit" => "units", "specifications" => { "Voltage" => "380V", "Frequency" => "50Hz" },
          "evidence" => "5 HZ-240 units, 380V/50Hz" } ],
        "commercial_terms" => { "incoterm" => "CIF", "destination" => "Hamburg" }
      })

    visit new_user_session_path
    fill_in "user_login", with: users(:one).email
    fill_in "user_password", with: "password123"
    click_button I18n.t("users.sessions.view.new.submit")
    visit inquiry_path(inquiry)

    assert_selector ".draft-preparation", text: "已准备好一份推荐草稿"
    assert_field "inquiry[extracted_data][products][0][unit_price]", with: "480.0"
    assert_selector ".catalog-candidate.is-selected", text: product.name
    assert_field "inquiry[extracted_data][products][0][specifications][Frequency]", with: "50Hz"
    FileUtils.mkdir_p(OUTPUT_ROOT)
    save_screenshot(OUTPUT_ROOT.join("inquiry-draft-desktop.png"), full: true)

    find("input[data-action='change->inquiry-review#keepRequested']").click
    assert_field "inquiry[extracted_data][products][0][name]", with: "Hydraulic Pump"
    assert_field "inquiry[extracted_data][products][0][unit_price]", with: ""

    page.current_window.resize_to(390, 1600)
    save_screenshot(OUTPUT_ROOT.join("inquiry-draft-mobile.png"), full: true)
  end
end
