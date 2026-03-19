class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def show
    locales = I18n.available_locales.map(&:to_s)

    @sitemap_urls = SeoPageRegistry.indexable.flat_map do |page|
      alternate_links = locales.map do |locale|
        { hreflang: locale, href: public_send(page.path_helper, locale: locale) }
      end
      alternate_links << { hreflang: "x-default", href: public_send(page.path_helper, locale: I18n.default_locale.to_s) }

      locales.map do |locale|
        {
          loc: public_send(page.path_helper, locale: locale),
          changefreq: page.changefreq,
          priority: page.priority,
          alternates: alternate_links
        }
      end
    end

    @lastmod = Date.current.iso8601
  end
end
