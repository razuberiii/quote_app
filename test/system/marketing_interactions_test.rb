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
    assert_text "From messy inquiry"
    assert_text "Buyer Room"
    assert_link "Try the Seller Demo"
    assert_link "Experience Buyer Room"
  end
end
