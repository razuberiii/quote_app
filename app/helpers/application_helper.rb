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

  def user_preferred_time_zone(user = current_user)
    name = user&.time_zone.to_s
    ActiveSupport::TimeZone[name] || ActiveSupport::TimeZone["UTC"]
  end

  def format_in_user_time(value, user = current_user, format: "%Y-%m-%d %H:%M")
    return "-" if value.blank?

    value.in_time_zone(user_preferred_time_zone(user)).strftime(format)
  end

  def relative_in_user_time(value, user = current_user)
    return nil if value.blank?

    t("datetime.ago", time: time_ago_in_words(value.in_time_zone(user_preferred_time_zone(user))), default: "%{time} ago")
  end

  def time_zone_options_for_select
    country_index = time_zone_country_index

    ActiveSupport::TimeZone.all
      .group_by { |zone| zone.tzinfo.name }
      .map do |zone_identifier, zones|
        clean_name = zone_identifier.split("/").last.tr("_", " ")
        zone = zones.find { |z| z.name == clean_name } || zones.first
        offset = zone.formatted_offset
        country_code = country_index[zone_identifier].to_s.upcase
        country_name = country_name_from_code(country_code)

        [
          "#{clean_name} (GMT#{offset})",
          zone.name,
          { data: { country: country_code, country_name: country_name, city: clean_name, gmt: "GMT#{offset}", tz_identifier: zone_identifier } }
        ]
      end
  end

  def time_zone_country_index
    @time_zone_country_index ||= begin
      index = {}
      TZInfo::Country.all.each do |country|
        country.zone_identifiers.each do |identifier|
          index[identifier] = country.code
        end
      end
      index
    rescue StandardError
      {}
    end
  end

  def country_name_from_code(code)
    return "" if code.blank?

    TZInfo::Country.get(code).name
  rescue StandardError
    ""
  end

  def template_watermark_text(template, fallback_text = nil)
    return nil unless template&.show_watermark

    return nil if template.respond_to?(:watermark_image) && template.watermark_image.attached?

    explicit_text = template.watermark_text.to_s.strip
    return explicit_text if explicit_text.present?

    template.watermark_text.to_s.strip.presence || fallback_text.to_s.strip.presence || "CONFIDENTIAL"
  end

  def template_watermark_image_url(template)
    return nil unless template&.show_watermark
    return nil unless template.respond_to?(:watermark_image) && template.watermark_image.attached?

    url_for(template.watermark_image)
  rescue StandardError
    nil
  end

  def template_signature_image_url(template)
    return nil unless template.respond_to?(:signature_image) && template.signature_image.attached?

    url_for(template.signature_image)
  rescue StandardError
    nil
  end

  def template_signature_name(template)
    return nil unless template.respond_to?(:signature_name)

    template.signature_name.to_s.strip.presence
  end

  def template_watermark_opacity(template)
    raw = template&.respond_to?(:watermark_opacity) ? template.watermark_opacity : nil
    percent = raw.to_i
    percent = 12 if percent <= 0
    percent = [ [ percent, 3 ].max, 40 ].min
    format("%.2f", percent / 100.0)
  end

  def app_breadcrumb_items
    return [] unless user_signed_in?

    case controller_path
    when "dashboard"
      [
        { label: t("nav.dashboard"), path: nil }
      ]
    when "customers"
      [
        { label: t("nav.customers"), path: nil }
      ]
    when "products"
      [
        { label: t("nav.products"), path: nil }
      ]
    when "product_presets", "addon_presets", "spec_presets"
      [
        { label: t("nav.products"), path: products_path },
        { label: t("nav.presets"), path: nil }
      ]
    when "quote_templates"
      [
        { label: t("nav.template"), path: nil }
      ]
    when "team_members"
      [
        { label: t("nav.team"), path: nil }
      ]
    when "team_invitations"
      [
        { label: t("nav.team"), path: team_members_path },
        { label: t("settings.invitations"), path: nil }
      ]
    when "admin/users"
      [
        { label: t("nav.admin"), path: nil }
      ]
    else
      []
    end
  end
end
