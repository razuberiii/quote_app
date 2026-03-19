class QuoteRevisionSummaryService
  DEFAULT_MAX_LINES = 6

  def initialize(quote:, max_lines: DEFAULT_MAX_LINES)
    @quote = quote
    @max_lines = max_lines
  end

  def call
    previous = previous_revision
    return nil if previous.blank?

    diff = QuoteRevisionDiffService.new(new_quote: @quote, old_quote: previous).call
    lines = build_lines(diff).first(@max_lines)
    total_changed = diff[:total_before].to_d != diff[:total_after].to_d
    return nil if lines.blank? && !total_changed

    {
      previous_revision_number: previous.revision_number.to_i,
      current_revision_number: @quote.revision_number.to_i,
      lines: lines,
      total_before: diff[:total_before].to_d,
      total_after: diff[:total_after].to_d,
      total_changed: total_changed
    }
  end

  private

  def previous_revision
    @quote.company.quotes.not_archived
      .where(quote_no: @quote.quote_no)
      .where("revision_number < ?", @quote.revision_number)
      .order(revision_number: :desc)
      .first
  end

  def build_lines(diff)
    lines = []
    modified_count = Array(diff[:modified_items]).size
    added_count = Array(diff[:added_items]).size
    removed_count = Array(diff[:removed_items]).size

    lines << I18n.t("quote_document.revision_summary.items_updated_count", count: modified_count) if modified_count.positive?
    lines << I18n.t("quote_document.revision_summary.items_removed_count", count: removed_count) if removed_count.positive?
    lines << I18n.t("quote_document.revision_summary.items_added_count", count: added_count) if added_count.positive?

    if pricing_changed?(diff)
      lines << I18n.t("quote_document.revision_summary.pricing_updated")
    end

    lines
  end

  def pricing_changed?(diff)
    Array(diff[:financial_changes]).any? ||
      Array(diff[:modified_items]).any? { |item| item[:quantity_changed] || item[:unit_price_changed] }
  end

end
