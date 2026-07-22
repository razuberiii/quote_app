class DealsController < ApplicationController
  before_action :load_deal, only: %i[show reply_question close reopen]

  def index
    return redirect_to quotes_path, status: :moved_permanently
    rows = current_user.company.quotes.not_archived.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :final_documents, :buyer_activities, quote_revisions: %i[buyer_questions change_requests]).order(updated_at: :desc)
    rows = rows.where(customer_id: params[:buyer_id]) if params[:buyer_id].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      rows = rows.left_joins(:customer, :quote_items).where(
        "customers.name ILIKE :term OR quotes.quote_no ILIKE :term OR quotes.custom_title ILIKE :term OR quote_items.description ILIKE :term",
        term:
      ).distinct
    end
    @deals = rows.map { |quote| [ quote, DealProgress.new(quote).call ] }
    @groups = {
      I18n.t("self_service.deals.groups.attention") => @deals.select { |_quote, progress| progress.attention && !%w[accepted closed].include?(progress.stage) },
      I18n.t("self_service.deals.groups.waiting") => @deals.select { |_quote, progress| progress.stage == "live" && !progress.attention },
      I18n.t("self_service.deals.groups.accepted") => @deals.select { |_quote, progress| progress.stage == "accepted" },
      I18n.t("self_service.deals.groups.closed") => @deals.select { |_quote, progress| progress.stage == "closed" }
    }
  end

  def show
    return redirect_to quote_path(@deal), status: :moved_permanently
    @progress = DealProgress.new(@deal).call
    @versions = @deal.quote_revisions.where.not(published_at: nil).ordered
    @questions = BuyerQuestion.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @requests = ChangeRequest.where(quote_revision_id: @versions.select(:id)).order(created_at: :desc)
    @responses = @deal.deal_responses.includes(attachment_attachment: :blob).order(received_at: :desc)
    @deliveries = @deal.version_deliveries.order(delivered_at: :desc)
    @activities = @deal.buyer_activities.order(created_at: :desc).limit(30)
    @acceptance = @deal.quote_acceptance
    @final_documents = @deal.final_documents.order(created_at: :desc)
    @tab = params[:tab].presence_in(%w[overview quote conversation versions documents]) || "overview"
  end

  def close
    outcome = params.require(:outcome).presence_in(%w[won lost cancelled])
    raise ActionController::BadRequest, "Outcome must be won, lost or cancelled" unless outcome
    attrs = { status: outcome }
    attrs[:won_at] = Time.current if outcome == "won"
    attrs[:win_reason] = params[:reason].presence || "other" if outcome == "won"
    attrs[:win_reason_detail] = params[:note].presence || "Closed from Deal workspace" if outcome == "won"
    attrs[:lost_at] = Time.current if outcome == "lost"
    attrs[:loss_reason] = params[:reason].presence || "other" if outcome == "lost"
    attrs[:loss_reason_detail] = params[:note].presence || "Closed from Deal workspace" if outcome == "lost"
    @deal.update!(attrs)
    redirect_to deal_path(@deal), notice: "Deal closed as #{outcome}."
  end

  def reopen
    @deal.update!(status: @deal.quote_acceptance.present? ? "accepted" : (@deal.quote_revisions.any? ? "sent" : "draft"),
      won_at: nil, lost_at: nil)
    redirect_to deal_path(@deal), notice: "Deal reopened with its full history intact."
  end

  def reply_question
    question = BuyerQuestion.where(quote_revision_id: @deal.quote_revisions.select(:id)).find(params[:question_id])
    question.update!(seller_reply: params.require(:buyer_question).require(:seller_reply), replied_at: Time.current)
    redirect_to deal_path(@deal, tab: "conversation"), notice: "Reply saved in this Deal."
  end

  private

  def load_deal
    @deal = current_user.company.quotes.includes(:customer, :inquiry, :quote_items, :quote_acceptance,
      :final_documents, :buyer_activities, quote_revisions: %i[buyer_questions change_requests]).find(params[:id])
  end
end
