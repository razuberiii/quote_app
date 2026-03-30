require "base64"
require "set"

module QuotesHelper
  def quote_money(amount, currency, show_code: false, show_symbol: true)
    code = currency.to_s.upcase.presence || "USD"
    return number_with_precision(amount.to_d, precision: 2, delimiter: ",") unless show_symbol

    symbol = Quote.currency_symbol_for(code)
    formatted = number_with_precision(amount.to_d, precision: 2, delimiter: ",")
    base = symbol == code ? "#{code} #{formatted}" : "#{symbol}#{formatted}"
    show_code && symbol != code ? "#{base} #{code}" : base
  end

  # Keep this customer-facing share message aligned with QuoteTemplate output locales.
  # If a new locale is added to QuoteTemplate::OUTPUT_LOCALES, also add the
  # matching quotes.share_message.* keys for that locale.
  # Returns a string with "__SHARE_URL__" as a placeholder that JS replaces
  # with the actual public share URL at runtime.
  def quote_share_message_template(quote, locale: I18n.locale)
    I18n.with_locale(locale) do
      customer = quote.customer
      customer_name = customer.contact_name.presence || customer.name
      total_text = quote_money(quote.display_amount, quote.currency)
      quote_date_text = quote.issued_on&.strftime("%Y-%m-%d")
      valid_until_text = quote.valid_until&.strftime("%Y-%m-%d")

      paragraphs = []
      paragraphs << [
        I18n.t("quotes.share_message.greeting", customer_name: customer_name),
        I18n.t("quotes.share_message.intro")
      ]
      paragraphs << [
        I18n.t("quotes.share_message.quote_line", quote_no: quote.quote_no),
        (I18n.t("quotes.share_message.quote_date_line", quote_date: quote_date_text) if quote_date_text.present?),
        (I18n.t("quotes.share_message.valid_until_line", valid_until: valid_until_text) if valid_until_text.present?),
        (I18n.t("quotes.share_message.payment_term_line", payment_term: quote.payment_term) if quote.payment_term.present?),
        I18n.t("quotes.share_message.total_line", total: total_text)
      ]
      paragraphs << [
        I18n.t("quotes.share_message.review_here"),
        "__SHARE_URL__"
      ]

      item_lines = share_message_item_lines(quote)
      paragraphs << item_lines if item_lines.any?

      revision_lines = share_message_revision_lines(quote)
      if revision_lines.any?
        paragraphs << [ I18n.t("quotes.share_message.revision_changes_title"), *revision_lines ]
      elsif quote.revision_number.to_i > 1
        paragraphs << [ I18n.t("quotes.share_message.revision_note") ]
      end

      paragraphs << [ I18n.t("quotes.share_message.closing") ]
      paragraphs
        .map { |lines| Array(lines).compact.reject(&:blank?).join("\n") }
        .reject(&:blank?)
        .join("\n\n")
    end
  end

  def quote_whatsapp_message_template(quote, locale: I18n.locale)
    quote_share_message_template(quote, locale: locale)
  end

  def quote_item_details_lines(item, show_symbol: true, template: nil)
    lines = []
    item.specification_pairs.each do |pair|
      lines << "Spec: #{pair[:key]} - #{pair[:value]}"
    end
    item.addon_charge_entries.each do |entry|
      amount_text =
        if template
          template_money(entry[:amount], item.quote&.currency || "USD", template, show_currency: show_symbol)
        else
          quote_money(entry[:amount], item.quote&.currency || "USD", show_symbol: show_symbol)
        end
      lines << "Add-on: #{entry[:name]} (#{amount_text})"
    end
    lines
  end

  def quote_trade_terms_section_title
    t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
  end

  def quote_logistics_section_title
    t("quotes.view.show.shipping_and_logistics", default: "Shipping & Logistics")
  end

  def quote_container_loading_section_title
    t("quotes.view.show.field_labels.container_loading", default: "Container Loading")
  end

  def quote_document_number_value(quote, document_kind)
    quote.document_number_for(document_kind)
  end

  def related_pi_display_name(pi_quote)
    base_name =
      pi_quote.custom_title.presence ||
      pi_quote.document_number_for("pi").presence ||
      pi_quote.quote_no

    "[PI] #{base_name}"
  end

  def quote_document_number_value_from_snapshot(snapshot, document_kind)
    source = snapshot.is_a?(Hash) ? snapshot : {}
    raw_quote_no = source["quote_no"].to_s.squish
    return raw_quote_no unless document_kind.to_s == "pi"

    formal = source["formal_closing_block"].is_a?(Hash) ? source["formal_closing_block"] : {}
    pi_number = (formal["pi_number"] || formal[:pi_number]).to_s.squish
    pi_number.presence || raw_quote_no
  end

  def quote_public_title(snapshot: nil, quote: nil, document_kind: "quote")
    if snapshot.is_a?(Hash)
      custom_title = snapshot["custom_title"].to_s.squish
      return custom_title if custom_title.present?

      first_item = Array(snapshot["quote_items"]).first || {}
      item_name = first_item["product_name"].to_s.squish.presence || first_item["description"].to_s.squish.presence
      return item_name if item_name.present?

      return quote_document_number_value_from_snapshot(snapshot, document_kind).to_s.squish
    end

    if quote.present?
      custom_title = quote.custom_title.to_s.squish
      return custom_title if custom_title.present?

      first_item = quote.quote_items.ordered.first
      item_name = first_item&.product&.name.to_s.squish.presence || first_item&.description.to_s.squish.presence
      return item_name if item_name.present?

      return quote_document_number_value(quote, document_kind).to_s.squish
    end

    ""
  end

  def quote_public_secondary_meta(snapshot: nil, quote: nil, template:, document_kind:, include_status: true)
    rows = []
    doc_number_label = template.resolved_document_number_label(document_kind)
    doc_number_value =
      if snapshot.is_a?(Hash)
        quote_document_number_value_from_snapshot(snapshot, document_kind)
      elsif quote.present?
        quote_document_number_value(quote, document_kind)
      end
    rows << { label: doc_number_label, value: doc_number_value } if doc_number_value.present?

    issued_on_value =
      if snapshot.is_a?(Hash)
        snapshot["issued_on"].to_s.squish
      else
        quote&.issued_on&.strftime("%Y-%m-%d").to_s
      end
    if issued_on_value.present?
      date_label = document_kind.to_s == "pi" ? t("quote_document.labels.pi_date") : t("quote_document.labels.quote_date")
      rows << { label: date_label, value: issued_on_value }
    end

    if quote.present? && quote.respond_to?(:revision_number) && quote.revision_number.to_i.positive?
      rows << { label: t("quote_document.labels.version", default: "Version"), value: "V#{quote.revision_number}" }
    end

    if include_status && quote.present?
      rows << { label: t("quote_document.labels.status"), value: quote_status_badge(quote.status) }
    end

    rows
  end

  def quote_public_snapshot_item_specs(raw_item)
    item = raw_item.is_a?(Hash) ? raw_item.stringify_keys : {}
    source = item["specifications"].presence || item["spec_snapshot"]

    Array(source).filter_map do |entry|
      row = entry.is_a?(Hash) ? entry.stringify_keys : {}
      key = row["key"].to_s.squish
      value = row["value"].to_s.squish
      next if key.blank? || value.blank?

      { key: key, value: value }
    end
  end

  def quote_public_snapshot_item_addons(raw_item)
    item = raw_item.is_a?(Hash) ? raw_item.stringify_keys : {}
    source = item["addon_charges"].presence || item["addon_snapshot"]

    Array(source).filter_map do |entry|
      row = entry.is_a?(Hash) ? entry.stringify_keys : {}
      name = row["name"].to_s.squish
      amount_raw = row["amount"]
      next if name.blank? || amount_raw.blank?

      amount = BigDecimal(amount_raw.to_s).round(2).to_s("F")
      { name: name, amount: amount }
    rescue ArgumentError
      next
    end
  end

  def quote_scope_list_nodes(scope_text)
    quote_internal_scope_nodes(scope_text)
  end

  def quote_internal_scope_items(scope_text)
    scope_text.to_s.lines.filter_map do |line|
      cleaned = line.to_s.strip
      cleaned = cleaned.sub(/\A[\-\*\u2022]+\s*/, "")
      cleaned.presence
    end
  end

  def quote_internal_scope_nodes(scope_text)
    scope_text.to_s.lines.filter_map do |line|
      raw = line.to_s
      next if raw.strip.blank?

      indent = raw[/\A\s*/].to_s.length
      cleaned = raw.strip.sub(/\A(?:[\-\*\u2022]|\d+[\.\)])+\s*/, "")
      next if cleaned.blank?

      level =
        if indent >= 4
          3
        elsif indent >= 2
          2
        else
          1
        end

      { level: level, text: cleaned }
    end
  end

  def quote_internal_fact_lines(value)
    value.to_s.lines.map { |line| line.to_s.strip }.reject(&:blank?)
  end

  def quote_internal_long_fact?(value, threshold: 70)
    quote_internal_fact_lines(value).any? { |line| line.length > threshold } || value.to_s.include?("\n")
  end

  def quote_internal_collapsible_kv_entries?(entries, max_visible: 3, length_threshold: 72)
    return false if entries.blank?
    return true if entries.size > max_visible

    entries.any? do |entry|
      entry_hash = entry.respond_to?(:to_h) ? entry.to_h : {}
      key = entry_hash[:key] || entry_hash["key"] || entry_hash[:name] || entry_hash["name"]
      value = entry_hash[:value] || entry_hash["value"] || entry_hash[:amount] || entry_hash["amount"]
      "#{key} #{value}".strip.length > length_threshold
    end
  end

  def quote_internal_item_detail_preview_count(entries, default_visible: 2, long_entry_threshold: 72)
    normalized = Array(entries)
    return 0 if normalized.empty?

    has_long_entry = normalized.any? do |entry|
      entry_hash = entry.respond_to?(:to_h) ? entry.to_h : {}
      key = entry_hash[:key] || entry_hash["key"] || entry_hash[:name] || entry_hash["name"]
      value = entry_hash[:value] || entry_hash["value"] || entry_hash[:amount] || entry_hash["amount"]
      "#{key} #{value}".strip.length > long_entry_threshold
    end

    return 1 if has_long_entry

    [ default_visible, normalized.size ].min
  end

  def quote_inline_disclosure_more_label(remaining_count)
    count = [ remaining_count.to_i, 0 ].max
    t("quotes.view.show.disclosure.more_count", count: count)
  end

  def quote_inline_disclosure_collapse_label
    t("quotes.view.show.disclosure.collapse")
  end

  def quote_formal_closing_settlement_rows(formal_closing_block_hash, quote:, document_kind:)
    source = formal_closing_block_hash.is_a?(Hash) ? formal_closing_block_hash : {}
    rows = [
      [ t("quote_document.labels.trade_terms", default: "Trade Terms"), source["trade_term"].presence || quote.trade_term ],
      [ t("quote_document.labels.payment_terms", default: "Payment Terms"), source["payment_term"].presence || quote.payment_term ],
      [ t("quotes.view.show.field_labels.delivery", default: "Delivery Time"), source["delivery_time"].presence || quote.delivery_notes ],
      [ t("quote_document.labels.bank_route", default: "Bank Route"), source["bank_route"] ],
      [ t("quote_document.labels.beneficiary_details", default: "Beneficiary Details"), source["beneficiary_details"] ],
      [ t("quote_document.labels.remittance_note", default: "Remittance Note"), source["remittance_note"] ]
    ]
    rows.filter_map { |label, value| quote_module_row(label, value) }
  end

  def quote_formal_closing_signature_flags(formal_closing_block_hash, has_seller_signature_image:, has_seller_stamp_image:)
    source = formal_closing_block_hash.is_a?(Hash) ? formal_closing_block_hash : {}
    {
      seller_signature_enabled: ActiveModel::Type::Boolean.new.cast(has_seller_signature_image),
      seller_stamp_enabled: ActiveModel::Type::Boolean.new.cast(has_seller_stamp_image),
      buyer_signature_line_enabled: ActiveModel::Type::Boolean.new.cast(source["buyer_signature_line_enabled"] || source[:buyer_signature_line_enabled])
    }
  end

  def quote_show_formal_closing_block?(formal_closing_block_hash, quote:, document_kind:, has_seller_signature_image:, has_seller_stamp_image:)
    source = formal_closing_block_hash.is_a?(Hash) ? formal_closing_block_hash : {}
    settlement_rows = quote_formal_closing_settlement_rows(source, quote: quote, document_kind: document_kind)
    signature_flags = quote_formal_closing_signature_flags(source, has_seller_signature_image: has_seller_signature_image, has_seller_stamp_image: has_seller_stamp_image)
    signature_visible =
      (signature_flags[:seller_signature_enabled] && has_seller_signature_image) ||
      signature_flags[:seller_stamp_enabled] ||
      signature_flags[:buyer_signature_line_enabled]

    settlement_rows.any? || signature_visible
  end

  def quote_supplementary_field_label(key)
    key_name = key.to_s
    {
      "hs_code" => t("quotes.view.form.hs_code", default: "HS Code"),
      "warranty_scope_note" => t("quotes.view.show.field_labels.warranty", default: "Warranty"),
      "support_scope_note" => t("quotes.view.show.field_labels.support", default: "Support"),
      "validity_clause_note" => t("quotes.view.show.field_labels.validity", default: "Validity"),
      "delivery_commitment_note" => t("quotes.view.show.field_labels.delivery", default: "Delivery"),
      "payment_clause_note" => t("quotes.view.show.field_labels.payment_terms", default: "Payment Terms"),
      "freight_note" => t("quotes.view.show.field_labels.freight", default: "Freight"),
      "container_type" => t("quotes.view.show.field_labels.container_type", default: "Container Type"),
      "shipping_scope_note" => t("quotes.view.show.field_labels.shipping_scope", default: "Shipping Scope"),
      "container_loading_note" => t("quotes.view.show.field_labels.container_loading", default: "Container Loading")
    }.fetch(key_name, key_name.humanize)
  end

  def quote_normalized_supplementary_hash(raw, section:)
    allowed_keys =
      case section.to_sym
      when :trade_terms
        Quote::ADVANCED_TRADE_TERMS_KEYS
      when :logistics
        Quote::ADVANCED_LOGISTICS_KEYS
      else
        []
      end
    source = raw.is_a?(Hash) ? raw : {}

    allowed_keys.each_with_object({}) do |key, acc|
      next unless source.key?(key) || source.key?(key.to_sym)

      cleaned = (source[key] || source[key.to_sym]).to_s.squish
      acc[key] = cleaned if cleaned.present?
    end
  end

  def quote_commercial_summary_rows(trade_terms_hash, summary_max_chars: nil)
    source = trade_terms_hash.is_a?(Hash) ? trade_terms_hash : {}
    [
      [ t("quotes.view.form.hs_code", default: "HS Code"), source["hs_code"] ],
      [ t("quotes.view.show.field_labels.delivery", default: "Delivery Time"), source["delivery_commitment_note"] ],
      [ t("quotes.view.show.field_labels.warranty", default: "Guarantee"), source["warranty_scope_note"] ],
      [ t("quotes.view.show.field_labels.support", default: "Online Support"), source["support_scope_note"] ],
      [ t("quotes.view.show.field_labels.validity", default: "Price Valid Time"), source["validity_clause_note"] ],
      [ t("quotes.view.show.field_labels.payment_terms", default: "Payment Term"), source["payment_clause_note"] ]
    ].filter_map { |label, value| quote_module_row(label, value, summary_max_chars: summary_max_chars) }
  end

  def quote_logistics_summary_rows(logistics_hash, summary_max_chars: nil)
    source = logistics_hash.is_a?(Hash) ? logistics_hash : {}
    [
      [ t("quotes.view.show.field_labels.freight", default: "Freight Note / Freight Basis"), source["freight_note"] ],
      [ t("quotes.view.show.field_labels.container_type", default: "Container Type"), source["container_type"] ],
      [ t("quotes.view.show.field_labels.shipping_scope", default: "Shipping Scope"), source["shipping_scope_note"] ]
    ].filter_map { |label, value| quote_module_row(label, value, summary_max_chars: summary_max_chars) }
  end

  def quote_container_loading_note(logistics_hash)
    source = logistics_hash.is_a?(Hash) ? logistics_hash : {}
    source["container_loading_note"].to_s.squish
  end

  def quote_container_loading_rows(container_loading_block_hash)
    source = container_loading_block_hash.is_a?(Hash) ? container_loading_block_hash : {}
    rows_source = source["rows"]
    rows =
      if rows_source.is_a?(Array)
        rows_source
      elsif rows_source.is_a?(Hash)
        rows_source.values
      else
        []
      end

    rows.filter_map do |row|
      row_hash = row.is_a?(Hash) ? row : {}
      variant = (row_hash["variant"] || row_hash[:variant]).to_s.squish
      container_type = (row_hash["container_type"] || row_hash[:container_type]).to_s.squish
      capacity = (row_hash["capacity"] || row_hash[:capacity]).to_s.squish
      note = (row_hash["note"] || row_hash[:note]).to_s.squish
      next if variant.blank? && container_type.blank? && capacity.blank? && note.blank?

      {
        variant: variant,
        container_type: container_type,
        capacity: capacity,
        note: note,
        position: (row_hash["position"] || row_hash[:position]).to_i
      }
    end.sort_by { |row| [ row[:position], row[:variant], row[:container_type] ] }
  end

  def quote_container_loading_headers(container_loading_block_hash)
    source = container_loading_block_hash.is_a?(Hash) ? container_loading_block_hash : {}
    header_source = source["headers"].is_a?(Hash) ? source["headers"] : {}
    defaults = Quote::DEFAULT_CONTAINER_LOADING_HEADERS

    defaults.each_with_object({}) do |(key, fallback), acc|
      value = header_source[key].to_s.squish
      value = fallback if value.blank?
      acc[key.to_sym] = value.first(Quote::MAX_CONTAINER_LOADING_HEADER_LENGTH)
    end
  end

  def quote_container_loading_note_enabled?(container_loading_block_hash, rows: nil)
    source = container_loading_block_hash.is_a?(Hash) ? container_loading_block_hash : {}
    return ActiveModel::Type::Boolean.new.cast(source["note_enabled"]) if source.key?("note_enabled")

    quote_container_loading_note_column?(rows)
  end

  def quote_module_row(label, raw_value, summary_max_chars: nil)
    cleaned = raw_value.to_s.squish
    return nil if cleaned.blank?

    summary_value, truncated = quote_module_summary_value(cleaned, max_chars: summary_max_chars)
    {
      label: label,
      value: summary_value,
      full_value: cleaned,
      truncated: truncated
    }
  end

  def quote_module_summary_value(value, max_chars:)
    text = value.to_s.squish
    return [ "", false ] if text.blank?
    return [ text, false ] unless max_chars.to_i.positive?
    return [ text, false ] if text.length <= max_chars.to_i

    [ "#{text.first(max_chars.to_i)}...", true ]
  end

  def quote_module_truncated_narrative_rows(rows)
    Array(rows).filter_map do |row|
      next unless row.is_a?(Hash)
      next unless row[:truncated]

      label = row[:label].to_s
      full_value = row[:full_value].to_s.squish
      next if label.blank? || full_value.blank?

      { label: label, value: full_value }
    end
  end

  def quote_configuration_block_rows(configuration_block_hash)
    source = configuration_block_hash.is_a?(Hash) ? configuration_block_hash : {}
    rows_source = source["rows"]
    rows =
      if rows_source.is_a?(Array)
        rows_source
      elsif rows_source.is_a?(Hash)
        rows_source.values
      else
        []
      end

    rows.filter_map do |row|
      row_hash = row.is_a?(Hash) ? row : {}
      label = (row_hash["label"] || row_hash[:label] || row_hash["key"] || row_hash[:key]).to_s.squish
      value = (row_hash["value"] || row_hash[:value]).to_s.squish
      next if label.blank? || value.blank?

      {
        label: label,
        value: value,
        source: (row_hash["source"] || row_hash[:source]).to_s,
        position: (row_hash["position"] || row_hash[:position]).to_i
      }
    end.sort_by { |row| [ row[:position], row[:label] ] }
  end

  def quote_detail_picture_items(detail_pictures_block_hash)
    source = detail_pictures_block_hash.is_a?(Hash) ? detail_pictures_block_hash : {}
    items_source = source["items"]
    items =
      if items_source.is_a?(Array)
        items_source
      elsif items_source.is_a?(Hash)
        items_source.values
      else
        []
      end

    items.filter_map do |item|
      item_hash = item.is_a?(Hash) ? item : {}
      image_blob_id = (item_hash["image_blob_id"] || item_hash[:image_blob_id]).to_s.squish
      next if image_blob_id.blank?

      {
        image_blob_id: image_blob_id,
        caption: (item_hash["caption"] || item_hash[:caption]).to_s.squish,
        source: (item_hash["source"] || item_hash[:source]).to_s.squish,
        position: (item_hash["position"] || item_hash[:position]).to_i
      }
    end.sort_by { |item| [ item[:position], item[:image_blob_id] ] }
  end

  def quote_detail_picture_image_src(item, inline_for_pdf: false)
    blob_id = item.is_a?(Hash) ? item[:image_blob_id].to_s : ""
    return nil if blob_id.blank?

    blob = quote_detail_picture_blob(blob_id)
    return nil if blob.blank?

    if inline_for_pdf
      payload = Base64.strict_encode64(blob.download)
      "data:#{blob.content_type};base64,#{payload}"
    else
      rails_blob_path(blob, disposition: "inline")
    end
  rescue StandardError
    nil
  end

  def quote_item_primary_image_blob_id(item)
    attachment = item&.effective_image_attachment
    attachment&.blob_id&.to_s
  rescue StandardError
    nil
  end

  def quote_pdf_primary_item_image_blob_ids(items)
    Array(items).filter_map { |item| quote_item_primary_image_blob_id(item) }.to_set
  end

  def quote_pdf_filtered_detail_picture_cards(detail_picture_items, main_item_blob_ids:, inline_for_pdf: true)
    excluded_blob_ids = main_item_blob_ids.is_a?(Set) ? main_item_blob_ids : Set.new(Array(main_item_blob_ids).map(&:to_s))

    Array(detail_picture_items).filter_map do |item|
      row = item.is_a?(Hash) ? item : {}
      blob_id = row[:image_blob_id].to_s
      next if blob_id.blank? || excluded_blob_ids.include?(blob_id)

      image_src = quote_detail_picture_image_src(row, inline_for_pdf: inline_for_pdf)
      next if image_src.blank?

      ratio = quote_pdf_detail_picture_ratio(blob_id)
      picture_kind =
        if ratio >= 1.7
          :wide
        elsif ratio < 0.9
          :tall
        else
          :normal
        end

      row.merge(image_src: image_src, ratio: ratio, picture_kind: picture_kind)
    end
  end

  def quote_pdf_detail_picture_rows(cards)
    rows = []
    queue = Array(cards)
    index = 0

    while index < queue.size
      current = queue[index]
      nxt = queue[index + 1]

      if nxt.blank?
        rows << { template: :single_center, max_height_mm: 58, items: [ current ] }
        index += 1
        next
      end

      current_kind = current[:picture_kind].to_sym
      next_kind = nxt[:picture_kind].to_sym

      template =
        if current_kind == :wide && next_kind == :wide
          :two_wide
        elsif current_kind == :normal && next_kind == :normal
          :two_normal
        elsif current_kind == :tall || next_kind == :tall
          :mixed
        else
          :two_normal
        end

      max_height_mm =
        case template
        when :two_wide then 30
        when :two_normal then 40
        when :mixed then 50
        else 40
        end

      rows << { template: template, max_height_mm: max_height_mm, items: [ current, nxt ] }
      index += 2
    end

    rows
  end

  def quote_pdf_detail_picture_ratio(blob_id, fallback: 1.4)
    blob = quote_detail_picture_blob(blob_id)
    return fallback unless blob.present?

    metadata = blob.metadata.is_a?(Hash) ? blob.metadata : {}
    width = metadata["width"].to_f
    height = metadata["height"].to_f
    return fallback if width <= 0 || height <= 0

    width / height
  rescue StandardError
    fallback
  end

  def quote_pdf_estimated_item_row_height_mm(item)
    return 8.5 unless item.present?

    name_text = item.product&.name.to_s.squish.presence || item.description.to_s.squish
    model_text = item.description.to_s.squish
    spec_rows = Array(item.specification_pairs)
    addon_rows = Array(item.addon_charge_entries)

    text_lines = 0.0
    text_lines += [ (name_text.length / 34.0).ceil, 1 ].max
    text_lines += (model_text.length / 50.0).ceil if model_text.present?
    text_lines += 1 + spec_rows.size if spec_rows.any?
    text_lines += 1 + addon_rows.size if addon_rows.any?

    text_height_mm = 4.0 + (text_lines * 3.2)
    image_height_mm = quote_item_primary_image_blob_id(item).present? ? 16.5 : 0
    [ text_height_mm, image_height_mm, 8.5 ].max
  end

  def quote_pdf_estimated_first_page_gap_mm(items:, filler_rows:, show_tax:, show_shipping:, filler_row_height_mm: 7.0)
    content_area_mm = 297.0 - 24.0
    footer_height_mm = 8.0
    header_mm = 26.0
    buyer_mm = 18.0
    table_header_mm = 9.0
    totals_margin_top_mm = 4.0
    filler_height_mm = filler_rows.to_i * filler_row_height_mm.to_f
    items_height_mm = Array(items).sum { |item| quote_pdf_estimated_item_row_height_mm(item) }
    totals_rows = 2 + (show_tax ? 1 : 0) + (show_shipping ? 1 : 0)
    totals_height_mm = 2.0 + (totals_rows * 6.2)
    used_mm = header_mm + buyer_mm + table_header_mm + items_height_mm + filler_height_mm + totals_margin_top_mm + totals_height_mm

    (content_area_mm - footer_height_mm - used_mm).round(2)
  end

  def quote_pdf_compact_kv_section_estimated_height_mm(row_count)
    rows = row_count.to_i
    return 0 if rows <= 0

    title_mm = 7.0
    body_padding_mm = 5.0
    row_mm = 4.6
    (title_mm + body_padding_mm + (rows * row_mm)).round(2)
  end

  def quote_container_loading_note_column?(rows, note_enabled: nil)
    return ActiveModel::Type::Boolean.new.cast(note_enabled) unless note_enabled.nil?

    Array(rows).any? do |row|
      row_hash = row.is_a?(Hash) ? row : {}
      (row_hash[:note] || row_hash["note"]).to_s.squish.present?
    end
  end

  def quote_revision_diff_context(quote)
    previous = previous_quote_revision_for(quote)
    return nil unless previous

    diff = QuoteRevisionDiffService.new(new_quote: quote, old_quote: previous).call
    return nil unless quote_diff_has_inline_changes?(diff)

    {
      previous_revision_number: previous.revision_number.to_i,
      current_revision_number: quote.revision_number.to_i,
      diff: diff
    }
  end

  def quote_diff_has_inline_changes?(diff)
    return false if diff.blank?

    diff[:added_items].present? ||
      diff[:removed_items].present? ||
      diff[:modified_items].present? ||
      diff[:commercial_changes].present? ||
      diff[:financial_changes].present? ||
      diff[:total_before].to_d != diff[:total_after].to_d
  end

  def quote_diff_item_map(diff)
    map = {}
    Array(diff[:added_items]).each { |item| map[item[:key]] = item.merge(change_type: :added) if item[:key].present? }
    Array(diff[:removed_items]).each { |item| map[item[:key]] = item.merge(change_type: :removed) if item[:key].present? }
    Array(diff[:modified_items]).each { |item| map[item[:key]] = item.merge(change_type: :modified) if item[:key].present? }
    map
  end

  def quote_diff_commercial_change(diff, field)
    field_name = field.to_s
    Array(diff[:commercial_changes]).find do |change|
      change_field = change[:field].to_s
      change_field == field_name || change_field.start_with?("#{field_name}.")
    end
  end

  def quote_diff_financial_change(diff, field)
    Array(diff[:financial_changes]).find { |change| change[:field].to_s == field.to_s }
  end

  def quote_item_diff_key(item, counters)
    signature = if item.respond_to?(:product_id) && item.product_id.present?
      "product:#{item.product_id}"
    else
      name = item.respond_to?(:description) ? item.description : nil
      "name:#{normalize_diff_text(item.respond_to?(:product) ? item.product&.name.presence || name : name)}"
    end
    counters[signature] += 1
    "#{signature}:#{counters[signature]}"
  end

  def quote_item_diff_key_from_snapshot_item(item, counters)
    product_id = item["product_id"] || item[:product_id]
    product_name = item["product_name"] || item[:product_name]
    description = item["description"] || item[:description]
    signature = if product_id.present?
      "product:#{product_id}"
    else
      "name:#{normalize_diff_text(product_name.presence || description)}"
    end
    counters[signature] += 1
    "#{signature}:#{counters[signature]}"
  end

  def quote_inline_diff_text(before, after)
    before_text = before.to_s
    after_text = after.to_s
    return after_text if before_text == after_text

    safe_join(
      [
        content_tag(:del, before_text, class: "quote-inline-old"),
        content_tag(:span, after_text, class: "quote-inline-new")
      ],
      " "
    )
  end

  def quote_stacked_diff_text(before, after)
    before_text = before.to_s
    after_text = after.to_s
    return content_tag(:span, after_text, class: "quote-diff-current") if before_text == after_text

    content_tag(:span, class: "quote-diff-stack") do
      safe_join(
        [
          content_tag(:del, before_text, class: "quote-diff-old"),
          content_tag(:span, after_text, class: "quote-diff-new")
        ]
      )
    end
  end

  def quote_inline_diff_money(before, after, currency, show_symbol:, template: nil)
    before_text = template.present? ? template_money(before, currency, template, show_currency: show_symbol) : quote_money(before, currency, show_symbol: show_symbol)
    after_text = template.present? ? template_money(after, currency, template, show_currency: show_symbol) : quote_money(after, currency, show_symbol: show_symbol)
    return after_text if before.to_d == after.to_d

    safe_join(
      [
        content_tag(:del, before_text, class: "quote-inline-old"),
        content_tag(:span, after_text, class: "quote-inline-new")
      ],
      " "
    )
  end

  def quote_stacked_diff_money(before, after, currency, show_symbol:, template: nil)
    before_text = template.present? ? template_money(before, currency, template, show_currency: show_symbol) : quote_money(before, currency, show_symbol: show_symbol)
    after_text = template.present? ? template_money(after, currency, template, show_currency: show_symbol) : quote_money(after, currency, show_symbol: show_symbol)
    return content_tag(:span, after_text, class: "quote-diff-current") if before.to_d == after.to_d

    content_tag(:span, class: "quote-diff-stack") do
      safe_join(
        [
          content_tag(:del, before_text, class: "quote-diff-old"),
          content_tag(:span, after_text, class: "quote-diff-new")
        ]
      )
    end
  end

  def quote_spec_rows_with_diff(specs, row_diff)
    normalized_specs = Array(specs).filter_map do |spec|
      key_display = spec["key"] || spec[:key]
      value = spec["value"] || spec[:value]
      next if key_display.to_s.strip.blank? && value.to_s.strip.blank?

      {
        key: key_display.to_s.strip,
        value: value.to_s,
        normalized_key: normalize_diff_text(key_display)
      }
    end

    return normalized_specs if row_diff.blank?

    spec_changes = row_diff[:spec_changes] || {}
    updated_queues = Array(spec_changes[:updated]).group_by { |change| normalize_diff_text(change[:key]) }
    added_remaining = Array(spec_changes[:added]).tally { |change| normalize_diff_text(change[:key]) }

    rows = normalized_specs.map do |row|
      updated_queue = updated_queues[row[:normalized_key]]
      updated = updated_queue&.shift
      if updated.present?
        row.merge(change_type: :updated, before: updated[:before].to_s, after: updated[:after].to_s)
      elsif added_remaining[row[:normalized_key]].to_i.positive?
        added_remaining[row[:normalized_key]] -= 1
        row.merge(change_type: :added)
      else
        row
      end
    end

    present_counts = rows.tally { |row| row[:normalized_key] }
    removed_rows = Array(spec_changes[:removed]).group_by { |change| normalize_diff_text(change[:key]) }.flat_map do |normalized_key, removed_group|
      overflow = [ removed_group.size - present_counts[normalized_key].to_i, 0 ].max
      next [] if overflow.zero?

      removed_group.first(overflow).map do |change|
        {
          key: change[:key].to_s,
          value: change[:value].to_s,
          normalized_key: normalized_key,
          change_type: :removed
        }
      end
    end

    rows + removed_rows
  end

  def quote_addon_rows_with_diff(addons, row_diff)
    normalized_addons = Array(addons).filter_map do |addon|
      name_display = addon["name"] || addon[:name]
      amount = addon["amount"] || addon[:amount]
      next if name_display.to_s.strip.blank?

      {
        name: name_display.to_s.strip,
        amount: amount.to_d,
        normalized_name: normalize_diff_text(name_display)
      }
    end

    return normalized_addons if row_diff.blank?

    addon_changes = row_diff[:addon_changes] || {}
    updated_queues = Array(addon_changes[:updated]).group_by { |change| normalize_diff_text(change[:name]) }
    added_remaining = Array(addon_changes[:added]).tally { |change| normalize_diff_text(change[:name]) }

    rows = normalized_addons.map do |row|
      updated_queue = updated_queues[row[:normalized_name]]
      updated = updated_queue&.shift
      if updated.present?
        row.merge(change_type: :updated, before: updated[:before].to_d, after: updated[:after].to_d)
      elsif added_remaining[row[:normalized_name]].to_i.positive?
        added_remaining[row[:normalized_name]] -= 1
        row.merge(change_type: :added)
      else
        row
      end
    end

    present_counts = rows.tally { |row| row[:normalized_name] }
    removed_rows = Array(addon_changes[:removed]).group_by { |change| normalize_diff_text(change[:name]) }.flat_map do |normalized_name, removed_group|
      overflow = [ removed_group.size - present_counts[normalized_name].to_i, 0 ].max
      next [] if overflow.zero?

      removed_group.first(overflow).map do |change|
        {
          name: change[:name].to_s,
          amount: change[:amount].to_d,
          normalized_name: normalized_name,
          change_type: :removed
        }
      end
    end

    rows + removed_rows
  end

  def quote_diff_changed?(diff, field)
    quote_diff_commercial_change(diff, field).present?
  end

  def template_money(amount, currency, template, show_currency: true)
    code = currency.to_s.upcase.presence || "USD"
    decimals = template&.amount_decimals.to_i
    decimals = 2 unless [ 0, 2 ].include?(decimals)
    delimiter =
      case template&.thousand_separator
      when "space" then " "
      when "none" then ""
      else ","
      end

    number = number_with_precision(amount.to_d, precision: decimals, delimiter: delimiter)
    return number unless show_currency

    mode = template&.currency_display_mode.presence || "symbol_prefix"
    symbol = Quote.currency_symbol_for(code)
    case mode
    when "code_prefix"
      "#{code} #{number}"
    when "code_suffix"
      "#{number} #{code}"
    else
      symbol == code ? "#{code} #{number}" : "#{symbol}#{number}"
    end
  end

  def contrast_text_color(hex_color)
    hex = hex_color.to_s.delete("#")
    return "#ffffff" unless hex.match?(/\A\h{6}\z/)

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    # Calculate relative luminance
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    # If luminance is low (dark color), use white text
    # If luminance is high (light color), use dark text
    luminance < 0.5 ? "#ffffff" : "#1f2937"
  end

  private

  def share_message_item_lines(quote)
    items = quote.quote_items.ordered.limit(3)
    return [] if items.blank?

    lines = [ I18n.t("quotes.share_message.items_title") ]
    lines.concat(items.map do |item|
      I18n.t(
        "quotes.share_message.item_line",
        product: item.product&.name.presence || item.description.presence || I18n.t("quotes.share_message.generic_item"),
        quantity: item.quantity.to_i,
        unit_price: quote_money(item.unit_price, quote.currency)
      )
    end)

    extra_count = quote.quote_items.size - items.size
    lines << I18n.t("quotes.share_message.extra_items_line", count: extra_count) if extra_count.positive?
    lines
  end

  def share_message_revision_lines(quote)
    previous_quote = previous_quote_revision_for(quote)
    return [] unless previous_quote

    diff = QuoteRevisionDiffService.new(new_quote: quote, old_quote: previous_quote).call
    summary = QuoteChangeSummaryService.new(
      diff: diff,
      currency: quote.currency,
      current_revision: quote.revision_number,
      previous_revision: previous_quote.revision_number
    ).call
    lines = summary.to_s.lines.map(&:strip).reject(&:blank?)
    header_prefix = I18n.t("quotes.change_summary.header_fallback")
    lines.reject! { |line| line.start_with?(header_prefix) || line == I18n.t("quotes.change_summary.overview_title") }
    lines.first(5)
  end

  def previous_quote_revision_for(quote)
    quote.customer.quotes.not_archived
      .where(quote_no: quote.quote_no)
      .where("revision_number < ?", quote.revision_number)
      .order(revision_number: :desc)
      .first
  end

  def normalize_diff_text(value)
    value.to_s.downcase.gsub(/\s+/, " ").strip
  end

  def quote_detail_picture_blob(blob_id)
    @quote_detail_picture_blob_cache ||= {}
    key = blob_id.to_s
    return @quote_detail_picture_blob_cache[key] if @quote_detail_picture_blob_cache.key?(key)

    @quote_detail_picture_blob_cache[key] = ActiveStorage::Blob.find_by(id: key)
  end
end
