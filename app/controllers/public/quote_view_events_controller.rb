module Public
  class QuoteViewEventsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: :create
    before_action :find_quote_share, only: :create

    def create
      return head :not_found unless @quote_share

      duration_ms = params.dig(:duration_ms).to_i
      return head :bad_request if duration_ms < 0

      @quote_share.quote_view_events.create!(duration_ms: duration_ms)
      head :ok
    end

    private

    def find_quote_share
      token = params[:quote_share_id]
      @quote_share = QuoteShare.find_by(token: token)
    end
  end
end
