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
    Array(diff[:commercial_changes]).find { |change| change[:field].to_s == field.to_s }
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
end
