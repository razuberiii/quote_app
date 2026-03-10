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
        label: t("recommended_move.move_to_fulfillment.label"),
        detail: t("recommended_move.move_to_fulfillment.detail")
      }
    elsif @quote.status.to_s == "won"
      {
        tone: "good",
        label: t("recommended_move.move_to_handoff.label"),
        detail: t("recommended_move.move_to_handoff.detail")
      }
    elsif @quote.workflow_state == "lost"
      {
        tone: "watch",
        label: t("recommended_move.reopen_if_interest_returns.label"),
        detail: t("recommended_move.reopen_if_interest_returns.detail")
      }
    elsif reopened_pending?
      {
        tone: "watch",
        label: t("recommended_move.update_and_reshare.label"),
        detail: t("recommended_move.update_and_reshare.detail")
      }
    elsif @quote.changes_requested_at.present?
      {
        tone: "watch",
        label: t("recommended_move.prepare_next_revision.label"),
        detail: t("recommended_move.prepare_next_revision.detail")
      }
    elsif first_share_at.blank?
      {
        tone: "watch",
        label: t("recommended_move.share_public_link.label"),
        detail: t("recommended_move.share_public_link.detail")
      }
    elsif first_view_at.blank?
      {
        tone: "watch",
        label: t("recommended_move.send_reminder.label"),
        detail: t("recommended_move.send_reminder.detail")
      }
    elsif expiring_soon?
      {
        tone: "urgent",
        label: t("recommended_move.close_before_expiry.label"),
        detail: t("recommended_move.close_before_expiry.detail")
      }
    else
      {
        tone: "good",
        label: t("recommended_move.follow_up_while_warm.label"),
        detail: t("recommended_move.follow_up_while_warm.detail")
      }
    end
  end

  def buyer_readiness
    if @quote.accepted_at.present?
      {
        value: t("buyer_readiness.committed.value"),
        detail: t("buyer_readiness.committed.detail")
      }
    elsif @quote.status.to_s == "won"
      {
        value: t("buyer_readiness.won.value"),
        detail: t("buyer_readiness.won.detail")
      }
    elsif @quote.changes_requested_at.present?
      {
        value: t("buyer_readiness.engaged.value"),
        detail: t("buyer_readiness.engaged.detail")
      }
    elsif total_views >= 2
      {
        value: t("buyer_readiness.warm.value"),
        detail: t("buyer_readiness.warm.detail", count: total_views)
      }
    elsif first_view_at.present?
      {
        value: t("buyer_readiness.interested.value"),
        detail: t("buyer_readiness.interested.detail")
      }
    elsif first_share_at.present?
      {
        value: t("buyer_readiness.cold.value"),
        detail: t("buyer_readiness.cold.detail")
      }
    else
      {
        value: t("buyer_readiness.not_started.value"),
        detail: t("buyer_readiness.not_started.detail")
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
        value: t("revision_scope.no_compare.value"),
        detail: t("revision_scope.no_compare.detail")
      }
    elsif item_changes.zero? && commercial_changes.zero?
      {
        value: t("revision_scope.no_change.value"),
        detail: t("revision_scope.no_change.detail")
      }
    else
      {
        value: t("revision_scope.changed.value", item_count: item_changes, term_count: commercial_changes),
        detail: t("revision_scope.changed.detail", item_count: item_changes, commercial_count: commercial_changes)
      }
    end
  end

  def review_notes
    notes = []
    notes << t("review_notes.accepted_on", date: format_date(@quote.accepted_at)) if @quote.accepted_at.present?
    notes << t("review_notes.marked_won_on", date: format_date(@quote.won_at)) if @quote.respond_to?(:won_at) && @quote.won_at.present?
    notes << t("review_notes.marked_lost_on", date: format_date(@quote.lost_at)) if @quote.respond_to?(:lost_at) && @quote.workflow_state == "lost" && @quote.lost_at.present?
    notes << t("review_notes.revision_requested_on", date: format_date(@quote.changes_requested_at)) if @quote.changes_requested_at.present?
    notes << t("review_notes.first_viewed_on", date: format_date(first_view_at)) if first_view_at.present?
    notes << t("review_notes.shared_times", count: share_count) if share_count.positive?
    notes << t("review_notes.valid_until", date: @quote.valid_until.strftime("%Y-%m-%d")) if @quote.valid_until.present?
    notes << t("review_notes.revision_reopened_on", date: format_date(@quote.reopened_at)) if reopened_pending?
    notes.first(4)
  end

  def t(key, **options)
    I18n.t("quotes.logic.decision_review.#{key}", **options)
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
