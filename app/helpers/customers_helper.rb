module CustomersHelper
  def customer_sort_link(label, key, current_sort:, current_direction:, query:, list_filter:)
    next_direction = current_sort == key && current_direction == "desc" ? "asc" : "desc"
    indicator =
      if current_sort == key
        current_direction == "desc" ? " ↓" : " ↑"
      else
        ""
      end

    link_to(
      "#{label}#{indicator}",
      customers_path(query:, list_filter:, sort: key, direction: next_direction),
      class: "customer-sort-link"
    )
  end
end
