class QuoteDecisionReviewService
  def initialize(quote:, revision_diff: nil)
    @quote = quote
    @revision_diff = revision_diff || {}
  end

  def call
    {
      recommended_move: recommended_move,
      buyer_readiness: buyer_readiness,
      revision_scope: revision_scope,
      review_notes: review_notes
    }
  end

  private

  def recommended_move
    if @quote.accepted_at.present?
      {
        tone: "good",
        label: "Move to fulfillment",
        detail: "Buyer has already accepted this revision. Shift from selling to delivery handoff."
      }
    elsif @quote.status.to_s == "won"
      {
        tone: "good",
        label: "Move to handoff",
        detail: "This revision is marked won internally. Coordinate delivery, paperwork, or onboarding."
      }
    elsif @quote.workflow_state == "lost"
      {
        tone: "watch",
        label: "Re-open only if interest returns",
        detail: "This revision was marked lost. Create a new revision if the buyer re-engages."
      }
    elsif reopened_pending?
      {
        tone: "watch",
        label: "Update and reshare",
        detail: "This quote is back in draft. Finish edits and generate a fresh public link."
      }
    elsif @quote.changes_requested_at.present?
      {
        tone: "watch",
        label: "Prepare next revision",
        detail: "Customer asked for changes. Use the request context and ship the next revision quickly."
      }
    elsif first_share_at.blank?
      {
        tone: "watch",
        label: "Share public link",
        detail: "No public link activity yet. Generate a share link before chasing buyer feedback."
      }
    elsif first_view_at.blank?
      {
        tone: "watch",
        label: "Send reminder",
        detail: "Quote has been shared but not viewed. Nudge the buyer before the thread goes cold."
      }
    elsif expiring_soon?
      {
        tone: "urgent",
        label: "Close before expiry",
        detail: "Buyer has engaged and the validity window is tight. Push decision or send a revision today."
      }
    else
      {
        tone: "good",
        label: "Follow up while warm",
        detail: "Buyer activity exists. Reconfirm timing, pricing fit, and next decision checkpoint."
      }
    end
  end

  def buyer_readiness
    if @quote.accepted_at.present?
      {
        value: "Committed",
        detail: "Accepted via quote workflow."
      }
    elsif @quote.status.to_s == "won"
      {
        value: "Won",
        detail: "Marked won internally."
      }
    elsif @quote.changes_requested_at.present?
      {
        value: "Engaged",
        detail: "Buyer asked for changes instead of going silent."
      }
    elsif total_views >= 2
      {
        value: "Warm",
        detail: "#{total_views} views recorded on the public link."
      }
    elsif first_view_at.present?
      {
        value: "Interested",
        detail: "Buyer has viewed the quote once."
      }
    elsif first_share_at.present?
      {
        value: "Cold",
        detail: "Shared externally, but no view recorded yet."
      }
    else
      {
        value: "Not Started",
        detail: "No public share or buyer engagement yet."
      }
    end
  end

  def revision_scope
    item_changes = @revision_diff.fetch(:modified_items, []).size +
      @revision_diff.fetch(:added_items, []).size +
      @revision_diff.fetch(:removed_items, []).size
    commercial_changes = @revision_diff.fetch(:commercial_changes, []).size

    if @revision_diff.blank?
      {
        value: "No compare",
        detail: "This revision has no previous version to compare."
      }
    elsif item_changes.zero? && commercial_changes.zero?
      {
        value: "No change",
        detail: "Current and previous revisions are commercially identical."
      }
    else
      {
        value: "#{item_changes} item / #{commercial_changes} term",
        detail: "Detected #{item_changes} item-level and #{commercial_changes} commercial change(s) versus the previous revision."
      }
    end
  end

  def review_notes
    notes = []
    notes << "Accepted on #{format_date(@quote.accepted_at)}." if @quote.accepted_at.present?
    notes << "Marked won on #{format_date(@quote.won_at)}." if @quote.respond_to?(:won_at) && @quote.won_at.present?
    notes << "Marked lost on #{format_date(@quote.lost_at)}." if @quote.respond_to?(:lost_at) && @quote.workflow_state == "lost" && @quote.lost_at.present?
    notes << "Revision requested on #{format_date(@quote.changes_requested_at)}." if @quote.changes_requested_at.present?
    notes << "First viewed on #{format_date(first_view_at)}." if first_view_at.present?
    notes << "Shared #{share_count} time#{'s' unless share_count == 1}." if share_count.positive?
    notes << "Valid until #{@quote.valid_until.strftime('%Y-%m-%d')}." if @quote.valid_until.present?
    notes << "Revision reopened on #{format_date(@quote.reopened_at)}." if reopened_pending?
    notes.first(4)
  end

  def first_share_at
    @first_share_at ||= @quote.quote_shares.minimum(:created_at)
  end

  def first_view_at
    @first_view_at ||= @quote.quote_shares.minimum(:first_viewed_at) || @quote.viewed_at
  end

  def total_views
    @total_views ||= @quote.quote_shares.sum(&:view_count).to_i
  end

  def share_count
    @share_count ||= @quote.quote_shares.size
  end

  def latest_share_at
    @latest_share_at ||= @quote.quote_shares.maximum(:created_at)
  end

  def expiring_soon?
    @quote.expires_in_days.present? && @quote.expires_in_days <= 3
  end

  def reopened_pending?
    return false if @quote.reopened_at.blank?
    return false unless @quote.workflow_state == "draft"

    latest_share_at.blank? || latest_share_at < @quote.reopened_at
  end

  def format_date(value)
    value&.strftime("%Y-%m-%d %H:%M")
  end
end
