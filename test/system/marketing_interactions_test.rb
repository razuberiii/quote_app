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
    assert_selector "h1.hero-fixed-headline", text: I18n.t("self_service.marketing.hero.title")
    assert_no_selector ".kinetic-headline__window"
    assert_text I18n.t("self_service.marketing.hero.body")
    assert_link I18n.t("self_service.marketing.hero.secondary")
  end
end
