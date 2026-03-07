module QuotesHelper
  def quote_money(amount, currency, show_code: false, show_symbol: true)
    code = currency.to_s.upcase.presence || "USD"
    return number_with_precision(amount.to_d, precision: 2, delimiter: ",") unless show_symbol

    symbol = Quote.currency_symbol_for(code)
    formatted = number_with_precision(amount.to_d, precision: 2, delimiter: ",")
    base = symbol == code ? "#{code} #{formatted}" : "#{symbol}#{formatted}"
    show_code && symbol != code ? "#{base} #{code}" : base
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
end
