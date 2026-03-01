module ApplicationHelper
  def seo_title(default = "Rubusoo")
    content_for?(:title) ? content_for(:title) : default
  end

  def seo_description
    return content_for(:meta_description) if content_for?(:meta_description)

    "Rubusoo helps B2B sales teams manage quote revisions, share live quote links, and export professional PDF/Excel documents."
  end

  def seo_canonical_url
    return content_for(:canonical_url) if content_for?(:canonical_url)
    return unless request.present?

    "#{request.base_url}#{request.path}"
  end

  def seo_robots
    return content_for(:meta_robots) if content_for?(:meta_robots)
    return "noindex,nofollow" if user_signed_in?
    return "noindex,nofollow" if devise_controller?
    return "noindex,nofollow" if controller_path == "email_verifications"
    return "noindex,nofollow" if controller_path == "email_changes"
    return "noindex,nofollow" if controller_path == "public/quote_shares"

    "index,follow"
  end

  def favicon_href
    icon_path = Rails.root.join("public", "icon.png")
    version = icon_path.exist? ? icon_path.mtime.to_i : Time.current.to_i
    "/icon.png?v=#{version}"
  end
end
