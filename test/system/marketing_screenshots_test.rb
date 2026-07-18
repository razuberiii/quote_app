require_relative "application_system_test_case"
require "fileutils"
require "selenium/webdriver"

if ENV["CHROMEDRIVER_PATH"].present?
  Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"]
end

class MarketingScreenshotsTest < ApplicationSystemTestCase
  driven_by :selenium,
    using: :headless_chrome,
    screen_size: [ 1440, 2200 ],
    options: {
      browser: :chrome,
      timeout: 120
    }

  VIEWPORTS = {
    desktop: [ 1440, 2200 ],
    tablet: [ 1024, 2000 ],
    mobile: [ 390, 2200 ]
  }.freeze

  PAGES = [
    { slug: "home", path: "/" },
    { slug: "pricing", path: "/pricing" },
    { slug: "seller-demo", path: "/seller-demo" },
    { slug: "buyer-demo", path: "/buyer-demo" }
  ].freeze

  test "capture marketing pages across common breakpoints" do
    output_root = Rails.root.join("tmp", "marketing_shots")
    FileUtils.rm_rf(output_root)
    FileUtils.mkdir_p(output_root)

    PAGES.each do |page_config|
      VIEWPORTS.each do |viewport_name, (width, height)|
        page.current_window.resize_to(width, height)
        visit page_config[:path]
        assert_current_path page_config[:path], ignore_query: true
        assert_no_text "Template is missing"

        wait_for_page_ready

        save_screenshot(output_root.join("#{page_config[:slug]}-#{viewport_name}.png"))
      end
    end
  end

  private

  def wait_for_page_ready
    assert_selector "body"
    sleep 0.25
  end
end
