module CustomersHelper
  def customer_sort_link(label, key, current_sort:, current_direction:, query:, list_filter:, follow_up_filter: "all", kpi_period: "week")
    next_direction = current_sort == key && current_direction == "desc" ? "asc" : "desc"
    indicator_class =
      if current_sort == key
        current_direction == "desc" ? "is-desc" : "is-asc"
      else
        "is-neutral"
      end
    indicator = current_sort == key ? (current_direction == "desc" ? "↓" : "↑") : "↕"

    link_to(
      customers_path(query:, list_filter:, follow_up_filter:, kpi_period:, sort: key, direction: next_direction),
      class: "customer-sort-link customer-sort-link-with-icon"
    ) do
      safe_join([
        content_tag(:span, label, class: "sort-label"),
        content_tag(:span, indicator, class: "sort-indicator #{indicator_class}", aria: { hidden: true })
      ])
    end
  end
end
