require_relative "application_system_test_case"
require "selenium/webdriver"

if ENV["CHROMEDRIVER_PATH"].present?
  Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"]
end

class MarketingInteractionsTest < ApplicationSystemTestCase
  driven_by :selenium,
    using: :headless_chrome,
    screen_size: [1440, 1600],
    options: {
      browser: :chrome,
      timeout: 120
    }

  test "quote revision control switches versions" do
    visit "/quote-revision-control"

    assert_selector "#quote-version-panel-v3", visible: true
    find("#quote-version-tab-v1").click

    assert_selector "#quote-version-panel-v1", visible: true
    assert_selector "#quote-version-tab-v1[aria-selected='true']"
    assert_selector "#quote-version-panel-v3", visible: :hidden
  end

  test "homepage flow switches panels" do
    visit "/"

    assert_selector "#homepage-flow-panel-sent", visible: true
    find("#homepage-flow-tab-follow_up").click

    assert_selector "#homepage-flow-panel-follow_up", visible: true
    assert_selector "#homepage-flow-tab-follow_up[aria-selected='true']"
    assert_selector "#homepage-flow-panel-sent", visible: :hidden
  end
end
