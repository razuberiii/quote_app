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
    summary = QuoteChangeSummaryService.new(diff: diff, currency: quote.currency).call
    lines = summary.to_s.lines.map(&:strip).reject(&:blank?)
    lines.reject! { |line| line == I18n.t("quotes.change_summary.header") }
    lines.first(5)
  end

  def previous_quote_revision_for(quote)
    quote.customer.quotes.not_archived
      .where(quote_no: quote.quote_no)
      .where("revision_number < ?", quote.revision_number)
      .order(revision_number: :desc)
      .first
  end
end
