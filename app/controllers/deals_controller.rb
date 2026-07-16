class DealsController < ApplicationController
  before_action :load_deal, only: %i[show reply_question]

  def index
    rows = current_user.company.quotes.not_archived.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :proforma_invoice, :buyer_activities, quote_revisions: %i[buyer_questions change_requests]).order(updated_at: :desc)
    rows = rows.where(customer_id: params[:buyer_id]) if params[:buyer_id].present?
    @deals = rows.map { |quote| [quote, DealProgress.new(quote).call] }
    @groups = {
      "Needs attention" => @deals.select { |_quote, progress| progress.attention && !%w[accepted closed].include?(progress.stage) },
      "Waiting on buyer" => @deals.select { |_quote, progress| progress.stage == "live" && !progress.attention },
      "Accepted" => @deals.select { |_quote, progress| progress.stage == "accepted" },
      "Closed" => @deals.select { |_quote, progress| progress.stage == "closed" }
    }
  end

  def show
    @progress = DealProgress.new(@deal).call
    @versions = @deal.quote_revisions.ordered
    @questions = BuyerQuestion.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @requests = ChangeRequest.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @activities = @deal.buyer_activities.order(created_at: :desc).limit(30)
    @acceptance = @deal.quote_acceptance
    @pi = @deal.proforma_invoice
    @tab = params[:tab].presence_in(%w[overview quote conversation versions documents]) || "overview"
  end

  def reply_question
    question = BuyerQuestion.where(quote_revision_id: @deal.quote_revisions.select(:id)).find(params[:question_id])
    question.update!(seller_reply: params.require(:buyer_question).require(:seller_reply), replied_at: Time.current)
    redirect_to deal_path(@deal, tab: "conversation"), notice: "Reply saved in this Deal."
  end

  private

  def load_deal
    @deal = current_user.company.quotes.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :proforma_invoice, :buyer_activities, quote_revisions: %i[buyer_questions change_requests]).find(params[:id])
  end
end
