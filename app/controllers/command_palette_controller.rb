class CommandPaletteController < ApplicationController
  def search
    query = params[:query].to_s.strip

    customers = current_user.company.customers.search(query).order(updated_at: :desc).limit(6)

    products_scope = current_user.company.products.order(updated_at: :desc)
    products_scope = products_scope.where("name ILIKE ?", "%#{query}%") if query.present?
    products = products_scope.limit(6)

    quotes = current_user.company.quotes
      .not_archived
      .latest_versions
      .search(query)
      .includes(:customer)
      .limit(6)

    render json: {
      labels: {
        actions: t("shortcuts.palette.groups.actions"),
        customers: t("shortcuts.palette.groups.customers"),
        products: t("shortcuts.palette.groups.products"),
        quotes: t("shortcuts.palette.groups.quotes"),
        no_results: t("shortcuts.palette.no_results")
      },
      actions: [
        {
          label: t("shortcuts.palette.actions.create_customer"),
          path: new_customer_path
        },
        {
          label: t("shortcuts.palette.actions.create_product"),
          path: new_product_path
        },
        {
          label: t("shortcuts.palette.actions.create_quote"),
          command: "open_quote_picker"
        }
      ],
      customers: customers.map do |customer|
        {
          label: customer.name,
          path: customer_path(customer)
        }
      end,
      products: products.map do |product|
        {
          label: product.name,
          meta: product.sku.presence,
          path: product_path(product)
        }
      end,
      quotes: quotes.map do |quote|
        {
          label: quote.title,
          sublabel: quote.quote_no,
          meta: quote.customer&.name,
          path: quote_path(quote)
        }
      end
    }
  end
end
