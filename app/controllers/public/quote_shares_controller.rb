module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"

    def show
      @share = QuoteShare.includes(:quote, company: :quote_templates).find_by!(token: params[:token])
      @share.track_view!
      @share.reload
      @snapshot = @share.snapshot
      @share.company.ensure_default_template!
      @template = @share.quote.template || @share.company.quote_template_or_default
      @template = @share.company.quote_templates.order(:created_at).first if @template&.new_record?
      @document_kind = @template.normalize_document_kind(params[:doc].presence || @template.default_document_kind)
    end
  end
end
