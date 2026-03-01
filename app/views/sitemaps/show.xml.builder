xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @sitemap_urls.each do |entry|
    xml.url do
      xml.loc entry[:loc]
      xml.lastmod @lastmod
      xml.changefreq entry[:changefreq]
      xml.priority entry[:priority]
    end
  end
end
