module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"

    def show
      @share = QuoteShare.includes(:quote, company: :quote_templates).find_by!(token: params[:token])
      @share.track_view! unless internal_preview_request?
      @share.reload
      @snapshot = @share.snapshot
      @share.company.ensure_default_template!
      @template = @share.quote.template || @share.company.quote_template_or_default
      @template = @share.company.quote_templates.order(:created_at).first if @template&.new_record?
      @document_kind = @template.normalize_document_kind(params[:doc].presence || @template.default_document_kind)
    end

    private

    def internal_preview_request?
      return false unless params[:preview].to_s == "1"
      return false unless respond_to?(:current_user) && current_user.present?

      current_user.company_id == @share.company_id
    end
  end
end
