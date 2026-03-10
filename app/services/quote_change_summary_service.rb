class QuoteChangeSummaryService
  include ActiveSupport::NumberHelper

  def initialize(diff:, currency:)
    @diff = diff
    @currency = currency
  end

  def call
    lines = [ I18n.t("quotes.change_summary.header"), "" ]

    @diff[:modified_items].each do |item|
      if item[:quantity_before] != item[:quantity_after]
        lines << I18n.t("quotes.change_summary.quantity_updated", product: item[:product_name], before: item[:quantity_before], after: item[:quantity_after])
      end

      if item[:unit_price_before] != item[:unit_price_after]
        lines << I18n.t("quotes.change_summary.unit_price_updated", product: item[:product_name], before: money(item[:unit_price_before]), after: money(item[:unit_price_after]))
      end
    end

    @diff[:added_items].each do |item|
      lines << I18n.t("quotes.change_summary.added_item", product: item[:product_name])
    end

    @diff[:removed_items].each do |item|
      lines << I18n.t("quotes.change_summary.removed_item", product: item[:product_name])
    end

    @diff.fetch(:commercial_changes, []).each do |change|
      lines << I18n.t("quotes.change_summary.commercial_updated", label: change[:label], before: truncate(change[:before]), after: truncate(change[:after]))
    end

    lines << "" if lines.last.present?
    lines << I18n.t("quotes.change_summary.total_updated", before: money(@diff[:total_before]), after: money(@diff[:total_after]))
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
