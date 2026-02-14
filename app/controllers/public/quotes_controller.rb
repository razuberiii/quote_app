module Public
  class QuotesController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :set_quote, only: [ :show ]
    layout "public", only: [ :show ]

    def show; end

    private

    def set_quote
      @quote = Quote.includes({ quote_items: :product }, :customer, :template, company: :quote_templates).find(params[:id])
      @template = @quote.template || @quote.company.quote_template_or_default
      @document_kind = @template.normalize_document_kind(params[:doc].presence || @template.default_document_kind)
    end
  end
end
