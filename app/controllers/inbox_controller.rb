class InboxController < ApplicationController
  def index
    @deals = deal_scope.map { |quote| [ quote, DealProgress.new(quote).call ] }
    @attention = @deals.select { |_quote, progress| progress.attention }
    @waiting = @deals.select { |_quote, progress| progress.stage == "live" && !progress.attention }
    @metrics = {
      attention: @attention.size,
      live_value: sum_for("live"),
      accepted: @deals.count { |_quote, progress| progress.stage == "accepted" },
      won: @deals.count { |quote, _progress| quote.status == "won" }
    }
  end

  private

  def deal_scope
    current_user.company.quotes.not_archived.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :final_documents, :buyer_activities, quote_revisions: %i[buyer_questions change_requests]).order(updated_at: :desc)
  end

  def sum_for(stage)
    @deals.select { |_quote, progress| progress.stage == stage }.sum { |quote, _progress| quote.grand_total.to_d }
  end
end
