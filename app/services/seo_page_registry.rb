class SeoPageRegistry
  Page = Struct.new(
    :key,
    :path_helper,
    :title_key,
    :description_key,
    :changefreq,
    :priority,
    :index,
    keyword_init: true
  ) do
    def index?
      ActiveModel::Type::Boolean.new.cast(index)
    end
  end

  class << self
    def fetch(key)
      pages[key.to_s]
    end

    def all
      pages.values
    end

    def indexable
      all.select(&:index?)
    end

    private

    def pages
      Rails.application.config_for(:seo_pages).each_with_object({}) do |(key, value), registry|
        registry[key.to_s] = Page.new(key: key.to_s, **value.symbolize_keys)
      end
    end
  end
end
