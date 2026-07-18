require_relative "application_system_test_case"
require "selenium/webdriver"

if ENV["CHROMEDRIVER_PATH"].present?
  Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"]
end

class MarketingInteractionsTest < ApplicationSystemTestCase
  driven_by :selenium,
    using: :headless_chrome,
    screen_size: [ 1440, 1600 ],
    options: {
      browser: :chrome,
      timeout: 120
    }

  test "homepage presents the channel-neutral Deal story" do
    visit "/"
    assert_selector "h1.kinetic-headline", text: /Turn/
    assert_selector "h1.kinetic-headline", text: /into decisions\./
    assert_selector "[data-product-story-target='phrase']", visible: true
    assert_text "Email, Excel, chat or PO goes in."
    assert_text "Buyer Room"
    assert_link "Open live demo"
    assert_link "Open interactive Buyer Demo"
  end
end
