class PiFromQuoteBuilder
  def initialize(source_quote, actor: nil, pi_options: {})
    @source_quote = source_quote
    @actor = actor
    @company = source_quote.company
    @pi_options = pi_options.is_a?(Hash) ? pi_options : {}
  end

  def call
    @source_quote.with_lock do
      existing_pi = find_existing_pi_quote
      return existing_pi if existing_pi.present?

      pi_quote = build_pi_quote
      pi_quote.save!
      pi_quote
    end
  rescue ActiveRecord::RecordNotUnique
    find_existing_pi_quote || raise
  end

  private

  def find_existing_pi_quote
    return nil unless Quote.column_names.include?("source_quote_id")

    @company.quotes.find_by(source_quote_id: @source_quote.id)
  end

  def build_pi_quote
    pi_quote = Quote.new(
      company: @company,
      customer: @source_quote.customer,
      template: resolve_pi_template,
      currency: @source_quote.currency,
      issued_on: resolved_issued_on,
      valid_until: @source_quote.valid_until,
      payment_term: option_or_source("payment_term", @source_quote.payment_term),
      trade_term: option_or_source("trade_term", @source_quote.trade_term),
      custom_title: pi_custom_title,
      status: "draft",
      notes: @source_quote.notes,
      tax_amount: @source_quote.tax_amount,
      shipping_amount: @source_quote.shipping_amount,
      discount_amount: @source_quote.discount_amount,
      terms_text: @source_quote.terms_text,
      legal_disclaimer: @source_quote.legal_disclaimer,
      delivery_notes: @source_quote.delivery_notes,
      scope_of_supply: @source_quote.scope_of_supply,
      advanced_mode: @source_quote.advanced_mode,
      advanced_trade_terms: @source_quote.advanced_trade_terms_state,
      advanced_logistics: @source_quote.advanced_logistics_state,
      advanced_visibility: @source_quote.advanced_visibility_data(template: @source_quote.template)
    )

    if Quote.column_names.include?("configuration_block")
      pi_quote.configuration_block = @source_quote.configuration_block_state
    end
    if Quote.column_names.include?("detail_pictures_block")
      pi_quote.detail_pictures_block = @source_quote.detail_pictures_block_state
    end
    if Quote.column_names.include?("container_loading_block")
      pi_quote.container_loading_block = @source_quote.container_loading_block_state
    end
    if Quote.column_names.include?("formal_closing_block")
      pi_quote.formal_closing_block = build_formal_closing_block
    end
    if Quote.column_names.include?("source_quote_id")
      pi_quote.source_quote_id = @source_quote.id
    end

    clone_items!(pi_quote)
    pi_quote
  end

  def clone_items!(pi_quote)
    item_columns = QuoteItem.column_names
    @source_quote.quote_items.ordered.each do |item|
      attrs = {
        product_id: item.product_id,
        description: item.description,
        unit_price: item.unit_price,
        quantity: item.quantity
      }
      attrs[:specifications] = item.specification_pairs if item_columns.include?("specifications")
      attrs[:addon_charges] = item.addon_charge_entries if item_columns.include?("addon_charges")
      attrs[:spec_snapshot] = item.specification_pairs if item_columns.include?("spec_snapshot")
      attrs[:addon_snapshot] = item.addon_charge_entries if item_columns.include?("addon_snapshot")
      attrs[:image_source] = item.image_source if item_columns.include?("image_source")
      attrs[:item_type] = item.item_type if item_columns.include?("item_type")
      new_item = pi_quote.quote_items.build(attrs)
      new_item.item_image.attach(item.item_image.blob) if item.item_image.attached?
    end
  end

  def resolve_pi_template
    @company.quote_templates
      .where(document_kind: "proforma_invoice")
      .order(default_template: :desc, created_at: :asc)
      .first || @source_quote.template || @company.quote_template_or_default
  end

  def pi_custom_title
    return @source_quote.custom_title if @source_quote.custom_title.present?

    "PI from #{@source_quote.quote_no}"
  end

  def option_or_source(key, source_value)
    value = @pi_options[key].to_s.squish
    value.presence || source_value
  end

  def resolved_issued_on
    raw = @pi_options["issued_on"].to_s
    return Date.current if raw.blank?

    Date.parse(raw)
  rescue ArgumentError
    Date.current
  end

  def build_formal_closing_block
    source_state = @source_quote.formal_closing_block_state
    merged = source_state.merge(
      "pi_number" => @pi_options["pi_number"].to_s.squish,
      "payment_term" => option_or_source("payment_term", @source_quote.payment_term),
      "trade_term" => option_or_source("trade_term", @source_quote.trade_term),
      "delivery_time" => option_or_source("delivery_time", @source_quote.delivery_notes),
      "bank_route" => @pi_options["bank_route"].to_s.squish,
      "beneficiary_details" => @pi_options["beneficiary_details"].to_s.squish,
      "remittance_note" => @pi_options["remittance_note"].to_s.squish,
      "buyer_signature_line_enabled" => ActiveModel::Type::Boolean.new.cast(@pi_options["buyer_signature_line_enabled"])
    )
    merged
  end
end
