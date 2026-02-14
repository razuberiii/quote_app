module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"

    def show
      @share = QuoteShare.includes(:quote, company: :quote_templates).find_by!(token: params[:token])
      @snapshot = @share.snapshot
      @template = @share.quote.template || @share.company.quote_template_or_default
      @document_kind = @template.normalize_document_kind(params[:doc].presence || @template.default_document_kind)
    end
  end
end
