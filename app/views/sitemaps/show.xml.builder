xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9", "xmlns:xhtml": "http://www.w3.org/1999/xhtml" do
  @sitemap_urls.each do |entry|
    xml.url do
      xml.loc entry[:loc]
      entry[:alternates].each do |alternate|
        xml.tag!("xhtml:link", rel: "alternate", hreflang: alternate[:hreflang], href: alternate[:href])
      end
      xml.lastmod @lastmod
      xml.changefreq entry[:changefreq]
      xml.priority entry[:priority]
    end
  end
end
