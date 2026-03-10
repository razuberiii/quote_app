require "ipaddr"

module Public
  class QuoteSharesController < ApplicationController
    skip_before_action :authenticate_user!
    layout "public"
    before_action :set_share
    before_action :set_template
    before_action :set_document_kind, only: %i[show]
    around_action :with_public_link_locale, only: %i[show accept request_revision]

    def show
      @share.track_view!(country: request_country, ip: request_client_ip, user_agent: request_user_agent) unless internal_preview_request?
      @snapshot = @share.snapshot
      @status_message = params[:status_message].presence
      set_newer_revision_context
    end

    def accept
      unless allow_public_accept_action?
        redirect_to public_quote_share_path(@share.token, status_message: t("public_quote_shares.flash.revision_not_actionable")) and return
      end

      accepted_at = Time.current

      @share.quote.update_columns(
        accepted_at: accepted_at,
        changes_requested_at: nil,
        changes_request_message: nil,
        request_reason: nil,
        status: "won",
        updated_at: accepted_at
      )
      redirect_to public_quote_share_path(@share.token, status_message: t("public_quote_shares.flash.quotation_accepted"))
    end

    def request_revision
      unless allow_public_revision_action?
        redirect_to public_quote_share_path(@share.token, status_message: t("public_quote_shares.flash.revision_not_actionable")) and return
      end

      selected_reason = params[:request_reason].to_s.strip
      custom_message = params[:client_message].to_s.strip
      selected_reason = "other" if selected_reason.blank? && custom_message.present?
      client_message = custom_message.presence
      @share.quote.update_columns(
        status: "negotiating",
        changes_requested_at: Time.current,
        request_reason: selected_reason.presence,
        changes_request_message: client_message,
        updated_at: Time.current
      )
      redirect_to public_quote_share_path(@share.token, status_message: t("public_quote_shares.flash.revision_request_sent"))
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
      cf_country = request.get_header("HTTP_CF_IPCOUNTRY").to_s.strip.upcase
      return cf_country if cf_country.present? && cf_country != "XX" && cf_country != "T1"

      request.location&.country.presence
    rescue StandardError
      nil
    end

    def request_client_ip
      candidates = []
      candidates << request.get_header("HTTP_CF_CONNECTING_IP")

      forwarded_for = request.get_header("HTTP_X_FORWARDED_FOR").to_s
      candidates.concat(forwarded_for.split(",").map(&:strip)) if forwarded_for.present?

      candidates << request.get_header("HTTP_X_REAL_IP")
      candidates << request.remote_ip
      candidates << request.ip

      candidates
        .compact
        .map { |value| value.to_s.strip }
        .reject(&:blank?)
        .find { |value| valid_ip_string?(value) }
    end

    def request_user_agent
      request.user_agent.to_s.strip.presence&.slice(0, 255)
    end

    def valid_ip_string?(value)
      IPAddr.new(value)
      true
    rescue IPAddr::InvalidAddressError, ArgumentError
      false
    end

    def allow_public_accept_action?
      quote = @share.quote
      return false if quote.expired_by_date?
      return false if quote.workflow_state == "expired"
      return false unless allow_public_action_base?(quote)

      %w[sent viewed negotiating].include?(quote.status.to_s)
    end

    def allow_public_revision_action?
      quote = @share.quote
      return false unless allow_public_action_base?(quote)

      quote.expired_by_date? || %w[sent viewed negotiating expired].include?(quote.status.to_s)
    end

    def allow_public_action_base?(quote)
      return false if quote.deleted?
      return false if quote.accepted_at.present?
      return false if quote.changes_requested_at.present?
      return false unless quote.latest_revision_for_quote_no?
      true
    end

    def set_newer_revision_context
      quote = @share.quote
      latest_quote = quote.company.quotes.not_archived.where(quote_no: quote.quote_no).order(revision_number: :desc).first
      return if latest_quote.blank? || latest_quote.id == quote.id

      @has_newer_revision = true
      latest_share = latest_quote.quote_shares.active.order(created_at: :desc).first
      latest_share ||= latest_quote.quote_shares.order(created_at: :desc).first
      return if latest_share.blank?

      @latest_share_url = public_quote_share_path(latest_share.token, doc: @document_kind)
    end

    def with_public_link_locale
      locale = @template&.output_locale_for(:public_link) || "en"
      I18n.with_locale(locale) { yield }
    end
  end
end
