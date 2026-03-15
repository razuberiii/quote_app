module CustomersHelper
  def customer_sort_link(label, key, current_sort:, current_direction:, query:, list_filter:, follow_up_filter: "all", kpi_period: "week")
    next_direction = current_sort == key && current_direction == "desc" ? "asc" : "desc"
    indicator_class =
      if current_sort == key
        current_direction == "desc" ? "is-desc" : "is-asc"
      else
        "is-neutral"
      end
    indicator_svg =
      if current_sort == key
        if current_direction == "desc"
          '<svg viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M8 3v10m0 0 3-3m-3 3-3-3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        else
          '<svg viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M8 13V3m0 0 3 3M8 3 5 6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        end
      else
        '<svg viewBox="0 0 16 16" fill="none" aria-hidden="true"><path d="M8 2v12m0-12 2.5 2.5M8 2 5.5 4.5M8 14l2.5-2.5M8 14l-2.5-2.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
      end

    link_to(
      customers_path(query:, list_filter:, follow_up_filter:, kpi_period:, sort: key, direction: next_direction),
      class: "customer-sort-link customer-sort-link-with-icon"
    ) do
      safe_join([
        content_tag(:span, label, class: "sort-label"),
        content_tag(:span, indicator_svg.html_safe, class: "sort-indicator customer-sort-link-icon #{indicator_class}", aria: { hidden: true })
      ])
    end
  end

  def whatsapp_follow_up_link(customer, message)
    phone = customer&.whatsapp_phone.to_s.gsub(/\D+/, "")
    return nil if phone.blank?
    return nil if message.to_s.strip.blank?

    encoded_message = ERB::Util.url_encode(message.to_s)
    "https://wa.me/#{phone}?text=#{encoded_message}"
  end

  def follow_up_signal_label(quote_view_status, quote_expiry_status, quote_signal_type = nil)
    if quote_signal_type.present? && I18n.exists?("follow_up.assistant.signal_labels.#{quote_signal_type}")
      return quote_signal_type
    end

    return "expired" if quote_expiry_status.to_s == "expired"
    return quote_view_status if %w[viewed not_viewed].include?(quote_view_status.to_s)

    "generic"
  end
end
