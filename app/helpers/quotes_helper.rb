module QuotesHelper
  def quote_money(amount, currency, show_code: false, show_symbol: true)
    code = currency.to_s.upcase.presence || "USD"
    return number_with_precision(amount.to_d, precision: 2) unless show_symbol

    symbol = Quote.currency_symbol_for(code)
    formatted = number_with_precision(amount.to_d, precision: 2)
    base = symbol == code ? "#{code} #{formatted}" : "#{symbol}#{formatted}"
    show_code && symbol != code ? "#{base} #{code}" : base
  end

  def quote_item_details_lines(item, show_symbol: true)
    lines = []
    item.specification_pairs.each do |pair|
      lines << "Spec: #{pair[:key]} - #{pair[:value]}"
    end
    item.addon_charge_entries.each do |entry|
      lines << "Add-on: #{entry[:name]} (#{quote_money(entry[:amount], item.quote&.currency || 'USD', show_symbol: show_symbol)})"
    end
    lines
  end
end
