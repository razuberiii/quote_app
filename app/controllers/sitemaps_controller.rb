class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def show
    @sitemap_urls = [
      { loc: root_url, changefreq: "daily", priority: "1.0" },
      { loc: demo_url, changefreq: "weekly", priority: "0.8" },
      { loc: sample_quote_url, changefreq: "weekly", priority: "0.7" },
      { loc: new_user_registration_url, changefreq: "weekly", priority: "0.6" },
      { loc: new_user_session_url, changefreq: "monthly", priority: "0.4" }
    ]
    @lastmod = Date.current.iso8601
  end
end
