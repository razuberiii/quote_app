class QuoteRevisionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @revision = current_user.company.quote_revisions.find(params[:id])
  end

  def create
    quote = current_user.company.quotes.find(params.require(:quote_id))
    result = RevisionPublisher.new(quote: quote, actor: current_user, url_options: { host: request.host, protocol: request.protocol }).call
    redirect_to deliver_deal_path(quote, version_id: result.revision.id), notice: "Version #{result.revision.number} is frozen. Choose how to deliver it."
  rescue RevisionPublisher::NotReady, RevisionPublisher::PlanLimitReached => error
    redirect_to edit_quote_path(quote), alert: error.message
  end
end
