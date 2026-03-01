class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def show
    @sitemap_urls = [
      { loc: root_url, changefreq: "daily", priority: "1.0" },
      { loc: foreign_trade_quotation_software_url, changefreq: "weekly", priority: "0.9" },
      { loc: quotation_crm_for_export_teams_url, changefreq: "weekly", priority: "0.9" },
      { loc: demo_url, changefreq: "weekly", priority: "0.8" },
      { loc: sample_quote_url, changefreq: "weekly", priority: "0.7" }
    ]
    @lastmod = Date.current.iso8601
  end
end
