class QuoteChangeSummaryService
  include ActiveSupport::NumberHelper

  def initialize(diff:, currency:)
    @diff = diff
    @currency = currency
  end

  def call
    lines = [ "Revision Update Summary:", "" ]

    @diff[:modified_items].each do |item|
      if item[:quantity_before] != item[:quantity_after]
        lines << "- #{item[:product_name]} quantity updated: #{item[:quantity_before]} -> #{item[:quantity_after]}"
      end

      if item[:unit_price_before] != item[:unit_price_after]
        lines << "- #{item[:product_name]} unit price updated: #{money(item[:unit_price_before])} -> #{money(item[:unit_price_after])}"
      end
    end

    @diff[:added_items].each do |item|
      lines << "- Added new item: #{item[:product_name]}"
    end

    @diff[:removed_items].each do |item|
      lines << "- Removed item: #{item[:product_name]}"
    end

    @diff.fetch(:commercial_changes, []).each do |change|
      lines << "- #{change[:label]} updated: #{truncate(change[:before])} -> #{truncate(change[:after])}"
    end

    lines << "" if lines.last.present?
    lines << "Total updated: #{money(@diff[:total_before])} -> #{money(@diff[:total_after])}"
    lines.join("\n")
  end

  private

  def money(amount)
    number_to_currency(
      amount.to_d,
      unit: Quote::CURRENCY_SYMBOLS[@currency.to_s.upcase] || "#{@currency} ",
      precision: 2
    )
  end

  def truncate(text)
    value = text.to_s
    value.length > 60 ? "#{value.first(57)}..." : value
  end
end
