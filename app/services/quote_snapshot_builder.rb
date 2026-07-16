class QuoteSnapshotBuilder
  def initialize(quote)
    @quote = quote
  end

  def as_json
    snapshot = @quote.attributes.except(
      "internal_note", "next_action", "follow_up_on", "status", "studio_state", "sent_at", "viewed_at",
      "accepted_at", "changes_requested_at", "won_at", "lost_at", "archived_at", "deleted_at",
      "win_reason", "win_reason_detail", "loss_reason", "loss_reason_detail", "stalled_reason",
      "stalled_reason_detail", "created_at", "updated_at", "lock_version"
    )
    snapshot.delete_if { |key, _value| key.end_with?("_at") }
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
    snapshot["configuration_block"] = @quote.configuration_block_data
    snapshot["detail_pictures_block"] = @quote.detail_pictures_block_data
    snapshot["container_loading_block"] = @quote.container_loading_block_data
    snapshot["formal_closing_block"] = @quote.formal_closing_block_data
    snapshot["seller_signature_image_url"] = if @quote.respond_to?(:seller_signature_image) && @quote.seller_signature_image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(@quote.seller_signature_image, only_path: true)
    end
    snapshot["seller_stamp_image_url"] = if @quote.respond_to?(:seller_stamp_image) && @quote.seller_stamp_image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(@quote.seller_stamp_image, only_path: true)
    end
    snapshot["spec_label"] = @quote.resolved_spec_label
    snapshot["addon_label"] = @quote.resolved_addon_label
    snapshot["custom_title"] = @quote.custom_title
    snapshot["quote_items"] = @quote.quote_items.ordered.map { |item| build_quote_item_snapshot(item) }
    add_sales_owner(snapshot)
    JSON.parse(JSON.generate(snapshot))
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
