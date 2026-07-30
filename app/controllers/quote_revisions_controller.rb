class QuoteRevisionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @revision = current_user.company.quote_revisions.find(params[:id])
  end

  def create
    quote = current_user.company.quotes.find(params.require(:quote_id))
    result = RevisionPublisher.new(quote: quote, actor: current_user, url_options: { host: request.host, protocol: request.protocol }).call
    redirect_to preview_quote_path(quote, published_revision_id: result.revision.id),
      notice: I18n.t("self_service.quote_core.published", number: result.revision.number)
  rescue RevisionPublisher::NotReady, RevisionPublisher::PlanLimitReached => error
    redirect_to quote_path(quote), alert: error.message
  end
end
