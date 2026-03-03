module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"
    before_action :set_share
    before_action :set_template
    before_action :set_document_kind, only: %i[show]

    def show
      @share.track_view!(country: request_country) unless internal_preview_request?
      @snapshot = @share.snapshot
      @status_message = params[:status_message].presence
      set_newer_revision_context
    end

    def accept
      unless allow_public_action?
        redirect_to public_quote_share_path(@share.token, status_message: "This revision is no longer actionable.") and return
      end

      @share.quote.update_columns(
        accepted_at: Time.current,
        changes_requested_at: nil,
        changes_request_message: nil,
        status: "won",
        updated_at: Time.current
      )
      redirect_to public_quote_share_path(@share.token, status_message: "Quotation accepted. Thank you.")
    end

    def request_revision
      unless allow_public_action?
        redirect_to public_quote_share_path(@share.token, status_message: "This revision is no longer actionable.") and return
      end

      selected_reasons = Array(params[:revision_reasons]).map { |reason| reason.to_s.strip }.reject(&:blank?).uniq
      custom_message = params[:client_message].to_s.strip
      message_parts = []
      message_parts << "Reasons: #{selected_reasons.join('; ')}" if selected_reasons.any?
      message_parts << "Custom: #{custom_message}" if custom_message.present?
      client_message = message_parts.join(" | ").presence
      @share.quote.update_columns(
        status: "negotiating",
        changes_requested_at: Time.current,
        changes_request_message: client_message,
        updated_at: Time.current
      )
      redirect_to public_quote_share_path(@share.token, status_message: "Revision request sent.")
    end

    private

    def set_share
      @share = QuoteShare.includes(:quote, company: :quote_templates).find_by!(token: params[:token])
    end

    def set_template
      @share.company.ensure_default_template!
      @template = @share.quote.template || @share.company.quote_template_or_default
      @template = @share.company.quote_templates.order(:created_at).first if @template&.new_record?
    end

    def set_document_kind
      @document_kind = @template.normalize_document_kind(params[:doc].presence || @template.default_document_kind)
    end

    def internal_preview_request?
      return false unless respond_to?(:current_user) && current_user.present?

      current_user.company_id == @share.company_id
    end

    def request_country
      request.location&.country.presence
    rescue StandardError
      nil
    end

    def allow_public_action?
      quote = @share.quote
      return false if quote.accepted_at.present?
      return false if quote.changes_requested_at.present?
      return false unless quote.latest_revision_for_quote_no?

      %w[sent viewed negotiating].include?(quote.status.to_s)
    end

    def set_newer_revision_context
      quote = @share.quote
      latest_quote = quote.company.quotes.where(quote_no: quote.quote_no).order(revision_number: :desc).first
      return if latest_quote.blank? || latest_quote.id == quote.id

      @has_newer_revision = true
      latest_share = latest_quote.quote_shares.active.order(created_at: :desc).first
      latest_share ||= latest_quote.quote_shares.order(created_at: :desc).first
      return if latest_share.blank?

      @latest_share_url = public_quote_share_path(latest_share.token, doc: @document_kind)
    end
  end
end
