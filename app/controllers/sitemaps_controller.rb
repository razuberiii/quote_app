class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def show
    @sitemap_urls = SeoPageRegistry.indexable.map do |page|
      {
        loc: public_send(page.path_helper),
        changefreq: page.changefreq,
        priority: page.priority
      }
    end
    @lastmod = Date.current.iso8601
  end
end
