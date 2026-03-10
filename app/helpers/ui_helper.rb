module UiHelper
  BUTTON_VARIANTS = {
    primary: "bg-indigo-600 text-white hover:bg-indigo-700 shadow-sm hover:shadow-md",
    secondary: "bg-white text-slate-700 border border-slate-200 hover:bg-slate-50",
    ghost: "bg-transparent text-slate-600 hover:bg-slate-100",
    danger: "bg-red-50 text-red-700 border border-red-200 hover:bg-red-100 hover:border-red-300"
  }.freeze

  NAV_ICONS = {
    dashboard: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M3 10.5 10 4l7 6.5V16a1 1 0 0 1-1 1h-4v-4H8v4H4a1 1 0 0 1-1-1v-5.5Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    customers: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M6.75 8.25a2.75 2.75 0 1 0 0-5.5 2.75 2.75 0 0 0 0 5.5ZM13.75 9.25a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0 4.5ZM2.75 16.25c0-2.35 2.02-4.25 4.5-4.25s4.5 1.9 4.5 4.25M11.75 16.25c0-1.79 1.48-3.25 3.3-3.25 1.81 0 3.2 1.46 3.2 3.25" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    products: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M4 6.5 10 3l6 3.5v7L10 17l-6-3.5v-7ZM4 6.5 10 10l6-3.5M10 10v7" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    presets: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M4 5.75A1.75 1.75 0 0 1 5.75 4h8.5A1.75 1.75 0 0 1 16 5.75v8.5A1.75 1.75 0 0 1 14.25 16h-8.5A1.75 1.75 0 0 1 4 14.25v-8.5ZM7 7h6M7 10h6M7 13h3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
    templates: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M5.5 3.5h9A1.5 1.5 0 0 1 16 5v10a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 4 15V5a1.5 1.5 0 0 1 1.5-1.5ZM7 7h6M7 10h6M7 13h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
    team: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M6.5 8A2.5 2.5 0 1 0 6.5 3a2.5 2.5 0 0 0 0 5ZM13.5 8.5A2 2 0 1 0 13.5 4.5a2 2 0 0 0 0 4ZM2.75 16c0-2.35 1.97-4.25 4.4-4.25 2.43 0 4.35 1.9 4.35 4.25M11.75 16c0-1.84 1.5-3.25 3.25-3.25 1.76 0 2.25 1.41 2.25 3.25" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    admin: '<svg viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M10 2.75 4.5 5v4.25c0 3.39 2.2 6.55 5.5 7.75 3.3-1.2 5.5-4.36 5.5-7.75V5L10 2.75ZM8 9.75l1.35 1.35L12.5 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>'
  }.freeze

  QUOTE_BADGE_COLORS = {
    "draft" => :blue,
    "pending" => :blue,
    "sent" => :blue,
    "viewed" => :indigo,
    "negotiating" => :amber,
    "won" => :green,
    "lost" => :red,
    "expired" => :red
  }.freeze

  CUSTOMER_BADGE_COLORS = {
    "new" => :blue,
    "potential" => :blue,
    "contacted" => :indigo,
    "following" => :indigo,
    "quoting" => :amber,
    "negotiating" => :amber,
    "paused" => :amber,
    "won" => :green,
    "closed" => :green,
    "lost" => :red,
    "inactive" => :red
  }.freeze

  def ui_button_classes(variant = :primary, extra_classes = nil)
    variant_key = variant.to_sym
    classes = [
      "app-ui-button",
      "app-ui-button--#{variant_key}",
      "inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-medium transition-all duration-200 active:scale-[0.98]",
      BUTTON_VARIANTS.fetch(variant_key, BUTTON_VARIANTS[:primary]),
      extra_classes
    ].compact
    classes.join(" ")
  end

  def ui_input_classes(extra_classes = nil)
    [
      "rounded-lg border-slate-200 focus:ring-indigo-500 focus:border-indigo-500",
      extra_classes
    ].compact.join(" ")
  end

  def ui_nav_link(label, path, icon: nil)
    normalized_path = path.to_s
    is_active = if normalized_path == dashboard_path
      current_page?(path)
    else
      request.path == normalized_path || request.path.start_with?("#{normalized_path}/")
    end
    content_tag :li do
      link_to path, class: [ "app-nav-link", ("is-active" if is_active) ].compact.join(" ") do
        safe_join(
          [
            content_tag(:span, (NAV_ICONS[icon&.to_sym] || NAV_ICONS[:dashboard]).html_safe, class: "app-nav-link-icon"),
            content_tag(:span, label, class: "app-nav-link-label")
          ]
        )
      end
    end
  end

  def ui_nav_icon(icon)
    (NAV_ICONS[icon&.to_sym] || NAV_ICONS[:dashboard]).html_safe
  end

  def status_badge(label, color = :blue, extra_classes = nil)
    content_tag :span,
                label,
                class: [
                  "app-status-badge",
                  "app-status-badge--#{color.to_sym}",
                  extra_classes
                ].compact.join(" ")
  end

  def quote_status_badge(status, label: nil, extra_classes: nil)
    normalized = status.to_s.downcase.presence || "draft"
    status_badge(label || normalized.humanize, QUOTE_BADGE_COLORS.fetch(normalized, :slate), extra_classes)
  end

  def customer_status_badge(status_or_customer, label: nil, extra_classes: nil)
    normalized = if status_or_customer.respond_to?(:status_css)
      status_or_customer.status_css.to_s
    else
      status_or_customer.to_s.parameterize(separator: "_")
    end

    text = label || (status_or_customer.respond_to?(:status_label) ? status_or_customer.status_label : normalized.humanize)
    status_badge(text, CUSTOMER_BADGE_COLORS.fetch(normalized, :slate), extra_classes)
  end

  def ui_empty_state(title:, body:, action_label: nil, action_path: nil, icon: :spark)
    icon_svg = case icon.to_sym
    when :customers
      '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M8.5 10a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7ZM16.5 11a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3 20c0-3.04 2.46-5.5 5.5-5.5S14 16.96 14 20M14 20c0-2.49 1.79-4.5 4-4.5s3 2.01 3 4.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    when :products
      '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 8.5 12 4l7 4.5v7L12 20l-7-4.5v-7ZM5 8.5 12 13l7-4.5M12 13v7" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    when :quotes
      '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M6.5 4h8A2.5 2.5 0 0 1 17 6.5v11A2.5 2.5 0 0 1 14.5 20h-8A2.5 2.5 0 0 1 4 17.5v-11A2.5 2.5 0 0 1 6.5 4ZM8 8h6M8 12h8M8 16h5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>'
    else
      '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m12 3 1.65 4.85L18.5 9.5l-4.85 1.65L12 16l-1.65-4.85L5.5 9.5l4.85-1.65L12 3Z" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    end

    content_tag :div, class: "app-empty-state" do
      safe_join(
        [
          content_tag(:div, icon_svg.html_safe, class: "app-empty-state-icon"),
          content_tag(:h3, title, class: "app-empty-state-title"),
          content_tag(:p, body, class: "app-empty-state-body"),
          (link_to(action_label, action_path, class: ui_button_classes(:primary, "app-empty-state-action")) if action_label.present? && action_path.present?)
        ].compact
      )
    end
  end
end
