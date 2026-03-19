class QuoteChangeSummaryService
  include ActiveSupport::NumberHelper

  def initialize(diff:, currency:, current_revision: nil, previous_revision: nil)
    @diff = diff
    @currency = currency
    @current_revision = current_revision
    @previous_revision = previous_revision
  end

  def call
    updated_items = Array(@diff[:modified_items])
    removed_items = Array(@diff[:removed_items])
    added_items = Array(@diff[:added_items])
    commercial_changes = Array(@diff[:commercial_changes])
    pricing_changes = resolved_pricing_changes

    lines = []
    lines << header_line
    lines << ""
    lines << I18n.t("quotes.change_summary.overview_title")
    lines += overview_lines(updated_items, removed_items, pricing_changes, commercial_changes)

    append_item_sections(lines, updated_items, removed_items, added_items)
    append_pricing_section(lines, pricing_changes)
    append_commercial_section(lines, commercial_changes)

    lines.compact.join("\n")
  end

  private

  def append_item_sections(lines, updated_items, removed_items, added_items)
    return if updated_items.blank? && removed_items.blank? && added_items.blank?

    lines << ""
    lines << I18n.t("quotes.change_summary.item_changes_title")

    if updated_items.any?
      lines << I18n.t("quotes.change_summary.updated_items_title")
      updated_items.each do |item|
        lines << I18n.t("quotes.change_summary.item_bullet", item: item[:product_name])
        item_detail_lines(item).each { |detail| lines << I18n.t("quotes.change_summary.detail_bullet", detail: detail) }
      end
      lines << ""
    end

    if removed_items.any?
      lines << I18n.t("quotes.change_summary.removed_items_title")
      removed_items.each do |item|
        lines << I18n.t("quotes.change_summary.item_bullet", item: item[:product_name])
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.qty_line", value: item[:quantity_before]))
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.unit_line", value: money(item[:unit_price_before])))
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.line_total_line", value: money(item[:line_total_before])))
      end
      lines << ""
    end

    if added_items.any?
      lines << I18n.t("quotes.change_summary.added_items_title")
      added_items.each do |item|
        lines << I18n.t("quotes.change_summary.item_bullet", item: item[:product_name])
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.qty_line", value: item[:quantity_after]))
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.unit_line", value: money(item[:unit_price_after])))
        lines << I18n.t("quotes.change_summary.detail_bullet", detail: I18n.t("quotes.change_summary.line_total_line", value: money(item[:line_total_after])))
      end
    end
  end

  def append_pricing_section(lines, pricing_changes)
    return if pricing_changes.blank?

    lines << ""
    lines << I18n.t("quotes.change_summary.pricing_changes_title")
    pricing_changes.each do |change|
      label = I18n.t("quotes.view.revision_diff.financial_fields.#{change[:field]}", default: change[:field].to_s.humanize)
      lines << I18n.t("quotes.change_summary.row_bullet", label: label, before: money(change[:before]), after: money(change[:after]))
    end
  end

  def append_commercial_section(lines, commercial_changes)
    return if commercial_changes.blank?

    lines << ""
    lines << I18n.t("quotes.change_summary.commercial_changes_title")
    commercial_changes.each do |change|
      label = I18n.t("quotes.view.revision_diff.fields.#{change[:field]}", default: change[:label])
      lines << I18n.t("quotes.change_summary.row_bullet", label: label, before: truncate(change[:before]), after: truncate(change[:after]))
    end
  end

  def overview_lines(updated_items, removed_items, pricing_changes, commercial_changes)
    lines = []
    lines << I18n.t("quotes.change_summary.overview_updated_items", count: updated_items.size) if updated_items.any?
    lines << I18n.t("quotes.change_summary.overview_removed_items", count: removed_items.size) if removed_items.any?
    lines << I18n.t("quotes.change_summary.overview_pricing_changed") if pricing_changes.any?
    lines << I18n.t("quotes.change_summary.overview_commercial_changed") if commercial_changes.any?
    lines
  end

  def item_detail_lines(item)
    lines = []
    lines << I18n.t("quotes.change_summary.qty_change_line", before: item[:quantity_before], after: item[:quantity_after]) if item[:quantity_changed]
    lines << I18n.t("quotes.change_summary.unit_change_line", before: money(item[:unit_price_before]), after: money(item[:unit_price_after])) if item[:unit_price_changed]
    if item[:line_total_before].to_d != item[:line_total_after].to_d
      lines << I18n.t("quotes.change_summary.line_total_change_line", before: money(item[:line_total_before]), after: money(item[:line_total_after]))
    end

    spec_changes = item[:spec_changes] || {}
    Array(spec_changes[:updated]).each do |change|
      lines << I18n.t("quotes.change_summary.spec_change_updated", key: change[:key], before: change[:before], after: change[:after])
    end
    Array(spec_changes[:added]).each do |change|
      lines << I18n.t("quotes.change_summary.spec_change_added", key: change[:key], value: change[:value])
    end
    Array(spec_changes[:removed]).each do |change|
      lines << I18n.t("quotes.change_summary.spec_change_removed", key: change[:key], value: change[:value])
    end

    addon_changes = item[:addon_changes] || {}
    Array(addon_changes[:updated]).each do |change|
      lines << I18n.t("quotes.change_summary.addon_change_updated", name: change[:name], before: money(change[:before]), after: money(change[:after]))
    end
    Array(addon_changes[:added]).each do |change|
      lines << I18n.t("quotes.change_summary.addon_change_added", name: change[:name], amount: money(change[:amount]))
    end
    Array(addon_changes[:removed]).each do |change|
      lines << I18n.t("quotes.change_summary.addon_change_removed", name: change[:name], amount: money(change[:amount]))
    end
    lines
  end

  def resolved_pricing_changes
    changes = Array(@diff[:financial_changes]).map { |change| change.symbolize_keys }
    return changes if changes.any? { |change| change[:field].to_s == "grand_total" }

    total_before = @diff[:total_before].to_d
    total_after = @diff[:total_after].to_d
    if total_before != total_after
      changes << { field: :grand_total, before: total_before, after: total_after }
    end
    changes
  end

  def money(amount)
    number_to_currency(
      amount.to_d,
      unit: Quote::CURRENCY_SYMBOLS[@currency.to_s.upcase] || "#{@currency} ",
      precision: 2
    )
  end

  def header_line
    if @current_revision.present? && @previous_revision.present?
      I18n.t("quotes.change_summary.header", current: @current_revision, previous: @previous_revision)
    else
      I18n.t("quotes.change_summary.header_fallback")
    end
  end

  def truncate(text)
    value = text.to_s
    value.length > 120 ? "#{value.first(117)}..." : value
  end
end
