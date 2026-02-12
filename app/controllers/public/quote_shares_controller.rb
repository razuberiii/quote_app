module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"

    def show
      @share = QuoteShare.includes(company: :quote_template).find_by!(token: params[:token])
      @snapshot = @share.snapshot
      @template = @share.company.quote_template_or_default
    end
  end
end
