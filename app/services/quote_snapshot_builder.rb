class QuoteSnapshotBuilder
  def initialize(quote)
    @quote = quote
  end

  def as_json
    snapshot = @quote.as_json
    snapshot["customer_name"] = @quote.customer.name
    snapshot["customer_contact_name"] = @quote.customer.contact_name
    snapshot["customer_address"] = @quote.customer.address
    snapshot["customer_phone"] = @quote.customer.formatted_phone
    snapshot["customer_email"] = @quote.customer.email
    snapshot["trade_term"] = @quote.trade_term
    snapshot["scope_of_supply"] = @quote.scope_of_supply
    snapshot["advanced_mode"] = @quote.advanced_mode
    snapshot["advanced_trade_terms"] = @quote.advanced_trade_terms_data
    snapshot["advanced_logistics"] = @quote.advanced_logistics_data
    snapshot["advanced_visibility"] = @quote.advanced_visibility_data
    snapshot["spec_label"] = @quote.resolved_spec_label
    snapshot["addon_label"] = @quote.resolved_addon_label
    snapshot["custom_title"] = @quote.custom_title
    snapshot["accepted_at"] = @quote.accepted_at
    snapshot["changes_requested_at"] = @quote.changes_requested_at
    snapshot["request_reason"] = @quote.request_reason
    snapshot["quote_items"] = @quote.quote_items.ordered.map { |item| build_quote_item_snapshot(item) }
    add_sales_owner(snapshot)
    snapshot
  end

  private

  def add_sales_owner(snapshot)
    return unless Customer.internal_owner_enabled?
    return unless @quote.customer.internal_owner_display_name != "-"

    snapshot["sales_owner_name"] = @quote.customer.internal_owner_display_name
    snapshot["customer_owner_name"] = @quote.customer.internal_owner_display_name
  end

  def build_quote_item_snapshot(item)
    snapshot = item.as_json
    snapshot["product_name"] = item.product&.name
    snapshot["specifications"] = item.specification_pairs
    snapshot["addon_charges"] = item.addon_charge_entries
    effective_image = item.effective_image_attachment
    snapshot["product_image_path"] = if effective_image.present?
      Rails.application.routes.url_helpers.rails_blob_path(effective_image, only_path: true)
    end
    snapshot["image_source"] = item.image_source
    snapshot
  end
end
