class QuotesController < ApplicationController
  require "base64"

  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate share send_reminder update_template reopen archive update_outcome_reason mark_sent mark_negotiating mark_outcome revert_to_sent undo_status_change public_preview]
  before_action :set_template, only: %i[show export_pdf export_xlsx share send_reminder update_template public_preview]
  before_action :set_form_products, only: %i[new edit create update duplicate]
  before_action :set_template_options, only: %i[new edit create update show duplicate update_template]
  around_action :with_quote_output_locale, only: %i[export_pdf export_xlsx]
  before_action :set_quote_document_locale, only: %i[show update_template]
  helper_method :quote_item_image_data_uri, :quote_logo_data_uri, :quote_watermark_data_uri

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.not_archived.latest_versions
    redirect_to @customer
  end

  def new
    @quote = @customer.quotes.new(currency: "USD", status: "draft", template: current_user.company.quote_template_or_default)
    prefill_scope_of_supply_from_template!(@quote)
    ensure_quote_item_row
  end

  def create
    unless current_user.can_create_quote?
      used = current_user.quote_count_for_limit
      redirect_to @customer, alert: t("quotes.flash.free_plan_limit_reached", used: used, limit: User::FREE_QUOTE_LIMIT) and return
    end

    @quote = @customer.quotes.new(quote_params)
    @quote.company = current_user.company
    @quote.status = "draft"
    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.save
      redirect_to quote_path(@quote, created: "1"), status: :see_other
    else
      ensure_quote_item_row
      render :new, status: :unprocessable_entity
    end
  end

  def show
    request.format = :html if request.format.turbo_stream? && params[:format] != "turbo_stream"
    @just_created = params[:created] == "1"

    @document_kind = resolved_document_kind
    set_superseded_context
    set_revision_compare_context
    set_decision_review_context
    set_decision_timeline_context

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "quote-page-content",
          partial: "quotes/show_content"
        )
      end
      format.html
    end
  end

  def edit
    unless @quote.can_edit_revision?
      redirect_to quote_path(@quote), alert: t("quotes.flash.revision_read_only") and return
    end
    ensure_quote_item_row
  end

  def update
    unless @quote.can_edit_revision?
      redirect_to quote_path(@quote), alert: t("quotes.flash.revision_read_only") and return
    end

    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.update(quote_params)
      redirect_to @quote, status: :see_other
    else
      ensure_quote_item_row
      render :edit, status: :unprocessable_entity
    end
  end

  def update_template
    unless @quote.can_edit_revision?
      redirect_to quote_path(@quote), alert: t("quotes.flash.template_change_not_allowed") and return
    end

    requested_template_id = params[:template_id].presence
    template = current_user.company.quote_templates.find_by(id: requested_template_id)
    template ||= current_user.company.quote_template_or_default
    template = current_user.company.quote_templates.order(:created_at).first if template&.new_record?
    unless template
      redirect_to quote_path(@quote), alert: t("quotes.flash.no_template_available") and return
    end

    @quote.update!(template: template)
    @template = template
    @document_kind = resolved_document_kind

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "quote-page-content",
          partial: "quotes/show_content"
        )
      end
      format.json { render json: { message: t("quotes.flash.template_updated") } }
      format.html { redirect_to quote_path(@quote, doc: @document_kind), notice: t("quotes.flash.template_updated") }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to quote_path(@quote), alert: t("quotes.flash.template_not_found")
  end

  def destroy
    unless @quote.can_delete_quote_family?
      redirect_to quote_path(@quote), alert: t("quotes.flash.delete_latest_revision_only") and return
    end

    deletion_time = Time.current
    family_scope = current_user.company.quotes.not_archived.where(quote_no: @quote.quote_no)
    affected_product_ids = family_scope.joins(:quote_items).where.not(quote_items: { product_id: nil }).distinct.pluck("quote_items.product_id")
    delete_attrs = { status: "expired", updated_at: deletion_time }
    delete_attrs[:deleted_at] = deletion_time if Quote.column_names.include?("deleted_at")
    family_scope.update_all(delete_attrs)
    current_user.company.quote_shares.where(quote_id: family_scope.select(:id)).update_all(expires_at: deletion_time, updated_at: deletion_time)
    ProductIntelligenceRefresher.refresh_products(affected_product_ids)

    redirect_to @quote.customer, status: :see_other, notice: t("quotes.flash.quote_thread_deleted", quote_no: @quote.quote_no)
  end

  def archive
    unless Quote.column_names.include?("archived_at")
      redirect_to quote_path(@quote), alert: t("quotes.flash.archive_not_ready") and return
    end

    unless @quote.can_archive_revision?
      redirect_to quote_path(@quote), alert: t("quotes.flash.archive_non_latest_only") and return
    end

    @quote.update!(archived_at: Time.current)
    latest = current_user.company.quotes.not_archived.where(quote_no: @quote.quote_no).order(revision_number: :desc).first
    redirect_target = latest || @quote.customer
    redirect_to redirect_target, status: :see_other, notice: t("quotes.flash.revision_archived", revision: @quote.revision_number)
  end

  def export_pdf
    kind = resolved_document_kind
    @document_kind = kind

    if Rails.env.test? && !wkhtmltopdf_available?
      render template: "quotes/export_pdf", layout: "pdf", formats: [ :html ] and return
    end

    if params[:debug].present?
      render template: "quotes/export_pdf", layout: "pdf", formats: [ :html ] and return
    end

    pdf_binary = nil
    pdf_client = wicked_pdf_client

    if use_wicked_pdf_renderer?(pdf_client)
      html = render_to_string(
        template: "quotes/export_pdf",
        formats: [ :html ],
        layout: "pdf"
      )

      pdf_binary = pdf_client.new.pdf_from_string(
        html,
        encoding: "UTF-8",
        page_size: "A4",
        margin: { top: 10, bottom: 10, left: 10, right: 10 },
        print_media_type: true,
        enable_local_file_access: true
      )
    else
      # Fallback for environments without wkhtmltopdf binary.
      pdf_binary = quote_exporter(kind, @template).to_pdf.render
    end

    mark_quote_as_sent_if_needed! unless params[:preview].present?

    preview_mode = params[:preview].present?
    send_data pdf_binary,
          filename: "#{kind}_#{@quote.quote_no}#{preview_mode ? '_preview' : ''}.pdf",
          type: "application/pdf",
          disposition: (preview_mode ? "inline" : "attachment")
  rescue StandardError => e
    Rails.logger.error("Quote PDF export failed: #{e.class} #{e.message}; wkhtmltopdf=#{configured_wkhtmltopdf_path.inspect}")
    redirect_to quote_path(@quote), alert: t("quotes.flash.pdf_export_failed")
  end

  def export_xlsx
    kind = resolved_document_kind
    exporter = quote_exporter(kind, @template)
    package = exporter.to_xlsx
    payload = package.to_stream.read
    exporter.cleanup_tempfiles!

    if params[:preview].present?
      send_data payload,
                filename: "#{kind}_#{@quote.quote_no}_preview.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "inline"
      return
    end

    mark_quote_as_sent_if_needed!

    send_data payload,
              filename: "#{kind}_#{@quote.quote_no}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  rescue StandardError
    exporter&.cleanup_tempfiles!
    raise
  end

  def public_preview
    @document_kind = resolved_document_kind
    @snapshot = QuoteSnapshotBuilder.new(@quote).as_json
    @preview_mode = true
    @status_message = nil
    @has_newer_revision = false
    @latest_share_url = nil
    @share = Struct.new(:quote, :company, :token).new(@quote, @quote.company, "preview")

    locale = (@template || @quote&.template || current_user.company.quote_template_or_default)&.output_locale_for(:webview) || I18n.locale
    I18n.with_locale(locale) do
      render "public/quote_shares/show", layout: "public"
    end
  end

  def duplicate
    unless @quote.can_create_new_revision?
      redirect_to quote_path(@quote), alert: t("quotes.flash.new_revision_not_available") and return
    end

    @customer = @quote.customer
    @quote = @quote.build_revision
    ensure_quote_item_row
    flash.now[:notice] = t("quotes.flash.revision_draft_created", quote_no: @quote.quote_no)
    render :new, formats: :html
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("Quote revision failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: t("quotes.flash.revision_schema_mismatch")
  end

  def share
    unless @quote.can_share_publicly?
      redirect_to quote_path(@quote), alert: t("quotes.flash.sharing_disabled") and return
    end

    publish_result = QuoteSharePublisher.new(
      @quote,
      document_kind: resolved_document_kind,
      url_options: trusted_public_url_options
    ).call
    share_url = publish_result.url
    mark_quote_as_sent_if_needed!

    respond_to do |format|
      format.json { render json: { url: share_url, token: publish_result.share.token } }
      format.html { redirect_to share_url }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Quote share failed: #{e.class} #{e.message}")
    respond_to do |format|
      format.json { render json: { message: t("quotes.flash.unable_create_public_share_link", errors: e.record.errors.full_messages.to_sentence) }, status: :unprocessable_entity }
      format.html { redirect_to quote_path(@quote), alert: t("quotes.flash.unable_create_public_share_link", errors: e.record.errors.full_messages.to_sentence) }
    end
  rescue StandardError => e
    Rails.logger.error("Quote share failed: #{e.class} #{e.message}")
    respond_to do |format|
      format.json { render json: { message: t("quotes.flash.unable_create_public_share_link_now") }, status: :internal_server_error }
      format.html { redirect_to quote_path(@quote), alert: t("quotes.flash.unable_create_public_share_link_now") }
    end
  end

  def send_reminder
    unless @quote.can_send_reminder?
      redirect_to quote_path(@quote), alert: t("quotes.flash.reminder_not_available") and return
    end

    unless verify_turnstile_for_html!(
      token: params[:cf_turnstile_response],
      on_missing: -> { redirect_to quote_path(@quote), alert: t("quotes.flash.reminder_verification_required") },
      on_failed: -> { redirect_to quote_path(@quote), alert: t("quotes.flash.reminder_verification_failed") }
    )
      return
    end

    QuoteReminderSender.new(
      @quote,
      document_kind: resolved_document_kind,
      url_options: trusted_public_url_options
    ).call
    redirect_to quote_path(@quote), status: :see_other, notice: t("quotes.flash.reminder_sent")
  rescue StandardError => e
    Rails.logger.error("Quote reminder failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), status: :see_other, alert: t("quotes.flash.unable_send_reminder")
  end

  def mark_sent
    unless @quote.can_mark_sent?
      redirect_to quote_path(@quote), alert: t("quotes.flash.mark_sent_not_available") and return
    end

    @quote.update!(
      status: "sent",
      sent_at: @quote.sent_at || Time.current,
      accepted_at: nil,
      win_reason: nil,
      win_reason_detail: nil,
      loss_reason: nil,
      loss_reason_detail: nil
    )
    redirect_to quote_path(@quote), status: :see_other, notice: t("quotes.flash.quote_marked_sent")
  end

  def mark_negotiating
    unless @quote.can_mark_negotiating?
      redirect_to quote_path(@quote), alert: t("quotes.flash.mark_negotiating_not_available") and return
    end

    undo_token = cache_status_undo_snapshot!(@quote)

    @quote.update!(
      status: "negotiating",
      accepted_at: nil,
      win_reason: nil,
      win_reason_detail: nil,
      loss_reason: nil,
      loss_reason_detail: nil
    )
    redirect_with_status_undo(@quote, undo_token, t("quotes.flash.quote_marked_negotiating"))
  end

  def mark_outcome
    target_status = params[:target_status].to_s

    case target_status
    when "won"
      unless @quote.can_mark_won?
        redirect_to quote_path(@quote), alert: t("quotes.flash.mark_won_not_available") and return
      end

      undo_token = cache_status_undo_snapshot!(@quote)

      @quote.update!(
        mark_won_params.merge(
          status: "won",
          accepted_at: Time.current,
          changes_requested_at: nil,
          changes_request_message: nil,
          request_reason: nil,
          loss_reason: nil,
          loss_reason_detail: nil,
          stalled_reason: nil,
          stalled_reason_detail: nil
        )
      )
      redirect_with_status_undo(@quote, undo_token, t("quotes.flash.quote_marked_won"))
    when "lost"
      unless @quote.can_mark_lost?
        redirect_to quote_path(@quote), alert: t("quotes.flash.mark_lost_not_available") and return
      end

      undo_token = cache_status_undo_snapshot!(@quote)

      @quote.update!(
        mark_lost_params.merge(
          status: "lost",
          accepted_at: nil,
          changes_requested_at: nil,
          changes_request_message: nil,
          request_reason: nil,
          win_reason: nil,
          win_reason_detail: nil,
          stalled_reason: nil,
          stalled_reason_detail: nil,
          final_amount: nil
        )
      )
      redirect_with_status_undo(@quote, undo_token, t("quotes.flash.quote_marked_lost"))
    else
      redirect_to quote_path(@quote), alert: t("quotes.flash.outcome_mark_not_available")
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to quote_path(@quote, outcome_modal: target_status), alert: @quote.errors.full_messages.to_sentence
  end

  def revert_to_sent
    unless @quote.can_revert_to_sent?
      redirect_to quote_path(@quote), alert: t("quotes.flash.mark_sent_not_available") and return
    end

    undo_token = cache_status_undo_snapshot!(@quote)

    @quote.update!(
      status: "sent",
      sent_at: @quote.sent_at || Time.current,
      accepted_at: nil,
      win_reason: nil,
      win_reason_detail: nil,
      loss_reason: nil,
      loss_reason_detail: nil,
      stalled_reason: nil,
      stalled_reason_detail: nil
    )

    redirect_with_status_undo(@quote, undo_token, t("quotes.flash.quote_marked_sent"))
  end

  def undo_status_change
    token = params[:token].to_s
    payload = consume_status_undo_snapshot!(@quote, token)
    unless payload
      redirect_to quote_path(@quote), alert: t("quotes.flash.undo_status_change_expired") and return
    end

    attrs = payload.fetch("attrs", {}).slice(*status_undo_attribute_names)
    attrs["updated_at"] = Time.current
    @quote.update_columns(attrs)

    redirect_to quote_path(@quote), status: :see_other, notice: t("quotes.flash.status_change_undone")
  end

  def reopen
    unless @quote.can_reopen?
      redirect_to quote_path(@quote), alert: t("quotes.flash.reopen_not_available") and return
    end

    reopen_attrs = {
      status: "draft",
      valid_until: (@quote.valid_until.present? && @quote.valid_until < Date.current ? nil : @quote.valid_until),
      viewed_at: nil,
      reminder_sent_at: nil,
      accepted_at: nil,
      won_at: nil,
      lost_at: nil,
      win_reason: nil,
      win_reason_detail: nil,
      loss_reason: nil,
      loss_reason_detail: nil,
      stalled_reason: nil,
      stalled_reason_detail: nil,
      changes_requested_at: nil,
      changes_request_message: nil,
      reopened_at: Time.current,
      updated_at: Time.current
    }
    reopen_attrs.delete(:won_at) unless Quote.column_names.include?("won_at")
    reopen_attrs.delete(:lost_at) unless Quote.column_names.include?("lost_at")

    @quote.update_columns(reopen_attrs)
    redirect_to quote_path(@quote), status: :see_other, notice: t("quotes.flash.quote_reopened")
  end

  def update_outcome_reason
    status = @quote.status.to_s
    unless %w[won lost].include?(status)
      redirect_to quote_path(@quote), alert: t("quotes.flash.reason_update_not_available") and return
    end

    attrs = outcome_reason_params_for(status)
    if @quote.update(attrs)
      redirect_to quote_path(@quote), status: :see_other, notice: t("quotes.flash.reason_updated")
    else
      redirect_to quote_path(@quote, fill_reason: 1), alert: @quote.errors.full_messages.to_sentence
    end
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:customer_id])
  end

  def set_quote
    Quote.expire_overdue_for_company!(current_user.company_id)
    @quote = current_user.company.quotes.not_archived.includes({ quote_items: :product }, :customer, :template, :quote_shares).find(params[:id])
  end

  def outcome_reason_params_for(status)
    case status
    when "won"
      params.require(:quote).permit(:win_reason, :win_reason_detail)
    when "lost"
      params.require(:quote).permit(:loss_reason, :loss_reason_detail)
    else
      {}
    end
  end

  def quote_params
    params.require(:quote).permit(
      :quote_no,
      :currency,
      :issued_on,
      :valid_until,
      :payment_term,
      :trade_term,
      :custom_title,
      :status,
      :negotiated,
      :final_amount,
      :win_reason,
      :win_reason_detail,
      :loss_reason,
      :loss_reason_detail,
      :stalled_reason,
      :stalled_reason_detail,
      :notes,
      :tax_amount,
      :shipping_amount,
      :discount_amount,
      :terms_text,
      :legal_disclaimer,
      :delivery_notes,
      :scope_of_supply,
      :template_id,
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity, :specifications_text, :addon_charges_text, :_destroy ]
    )
  end

  def mark_won_params
    params.require(:quote).permit(:win_reason, :win_reason_detail, :final_amount)
  end

  def mark_lost_params
    params.require(:quote).permit(:loss_reason, :loss_reason_detail)
  end

  def set_form_products
    @products = current_user.company.products.order(:name)
  end

  def set_template_options
    @template_options = current_user.company.quote_templates.ordered
  end

  def ensure_quote_item_row
    return if @quote.quote_items.reject(&:marked_for_destruction?).any?

    @quote.quote_items.build
  end

  def prefill_scope_of_supply_from_template!(quote)
    return if quote.scope_of_supply.present?
    return unless quote.template&.show_scope_of_supply?

    default_content = quote.template&.default_scope_of_supply_content.to_s
    quote.scope_of_supply = default_content if default_content.present?
  end

  def quote_exporter(kind = "quote", template = nil)
    require Rails.root.join("app/services/quote_exporter").to_s unless defined?(::QuoteExporter)
    template ||= @template
    @quote_exporters ||= {}
    cache_key = "#{kind}-#{template&.id || 'default'}"
    @quote_exporters[cache_key] ||= ::QuoteExporter.new(@quote, template: template, document_kind: kind)
  end

  def mark_quote_as_sent_if_needed!
    return unless @quote.can_mark_sent?

    now = Time.current
    @quote.update_columns(status: "sent", sent_at: (@quote.sent_at || now), updated_at: now)
  end

  def status_undo_attribute_names
    @status_undo_attribute_names ||= %w[
      status
      sent_at
      viewed_at
      accepted_at
      win_reason
      win_reason_detail
      loss_reason
      loss_reason_detail
      stalled_reason
      stalled_reason_detail
      final_amount
      changes_requested_at
      changes_request_message
      request_reason
      reopened_at
      reminder_sent_at
    ].select { |name| Quote.column_names.include?(name) }
  end

  def status_undo_cache_key(quote, token)
    "quote-status-undo:#{current_user.id}:#{quote.id}:#{token}"
  end

  def cache_status_undo_snapshot!(quote)
    token = SecureRandom.hex(12)
    payload = {
      "attrs" => quote.attributes.slice(*status_undo_attribute_names),
      "captured_at" => Time.current.to_i
    }
    Rails.cache.write(status_undo_cache_key(quote, token), payload, expires_in: 10.seconds)
    token
  end

  def consume_status_undo_snapshot!(quote, token)
    return nil if token.blank?

    key = status_undo_cache_key(quote, token)
    payload = Rails.cache.read(key)
    Rails.cache.delete(key)
    payload
  end

  def redirect_with_status_undo(quote, token, notice)
    redirect_to quote_path(quote),
                status: :see_other,
                notice: notice,
                flash: {
                  status_undo_token: token,
                  status_undo_expires_at: (Time.current + 10.seconds).iso8601
                }
  end

  def set_template
    current_user.company.ensure_default_template!
    candidate = if params[:template_id].present?
      current_user.company.quote_templates.find_by(id: params[:template_id])
    else
      @quote.template
    end

    @template = candidate || current_user.company.quote_template_or_default
    @template = current_user.company.quote_templates.order(:created_at).first if @template&.new_record?
  end

  def resolved_document_kind
    requested_kind = params[:document_kind].presence || params[:doc].presence || params[:kind].presence
    requested_kind ||= document_kind_from_referer
    @template.normalize_document_kind(requested_kind || default_document_kind)
  end

  def document_kind_from_referer
    return nil if request.referer.blank?

    uri = URI.parse(request.referer)
    referer_params = Rack::Utils.parse_nested_query(uri.query.to_s)
    referer_params["document_kind"].presence || referer_params["doc"].presence || referer_params["kind"].presence
  rescue URI::InvalidURIError
    nil
  end

  def default_document_kind
    @template.document_kind == "proforma_invoice" ? "pi" : "quote"
  end

  def set_quote_document_locale
    @quote_document_locale = (@template || @quote&.template || current_user.company.quote_template_or_default)&.output_locale_for(:webview) || I18n.locale
  end

  def with_quote_output_locale
    channel =
      case action_name
      when "show" then :webview
      when "export_pdf" then :pdf
      when "export_xlsx" then :excel
      else :webview
      end

    locale = (@template || @quote&.template || current_user.company.quote_template_or_default)&.output_locale_for(channel) || "en"
    I18n.with_locale(locale) { yield }
  end

  def quote_item_image_data_uri(item)
    product_image = item.product&.display_image
    return nil if product_image.blank?

    blob = product_image.blob
    payload = blob.download
    encoded = Base64.strict_encode64(payload)
    "data:#{blob.content_type};base64,#{encoded}"
  rescue StandardError
    nil
  end

  def quote_logo_data_uri
    return nil unless @template.show_logo && @quote.company.logo.attached?

    blob = @quote.company.logo.blob
    payload = blob.download
    encoded = Base64.strict_encode64(payload)
    "data:#{blob.content_type};base64,#{encoded}"
  rescue StandardError
    nil
  end

  def quote_watermark_data_uri
    return nil unless @template.show_watermark
    return nil unless @template.respond_to?(:watermark_image) && @template.watermark_image.attached?

    blob = @template.watermark_image.blob
    payload = blob.download
    encoded = Base64.strict_encode64(payload)
    "data:#{blob.content_type};base64,#{encoded}"
  rescue StandardError
    nil
  end

  def wkhtmltopdf_available?
    exe_path = configured_wkhtmltopdf_path.to_s
    return false if exe_path.blank?

    File.exist?(exe_path)
  end

  def use_wicked_pdf_renderer?(pdf_client)
    return false unless pdf_client
    return false unless wkhtmltopdf_available?

    true
  end

  def wicked_pdf_client
    begin
      require "wicked_pdf" unless defined?(::WickedPdf)
    rescue LoadError
      return nil
    end

    return nil unless defined?(::WickedPdf)

    ::WickedPdf
  end

  def configured_wkhtmltopdf_path
    return nil unless defined?(::WickedPdf) && ::WickedPdf.respond_to?(:config)

    ::WickedPdf.config[:exe_path]
  end

  def set_superseded_context
    latest = current_user.company.quotes.not_archived.where(quote_no: @quote.quote_no).order(revision_number: :desc).first
    return if latest.blank? || latest.id == @quote.id

    @has_newer_revision = true
    @latest_revision_quote = latest
  end

  def set_revision_compare_context
    @quote_revisions = current_user.company.quotes
      .not_archived
      .where(quote_no: @quote.quote_no)
      .includes(:quote_items)
      .order(revision_number: :desc)
      .to_a

    @previous_revision_quote = @quote_revisions
      .select { |revision| revision.revision_number.to_i < @quote.revision_number.to_i }
      .max_by { |revision| revision.revision_number.to_i }

    return if @previous_revision_quote.blank?

    @revision_diff = QuoteRevisionDiffService.new(
      new_quote: @quote,
      old_quote: @previous_revision_quote
    ).call
    @change_summary = QuoteChangeSummaryService.new(
      diff: @revision_diff,
      currency: @quote.currency
    ).call
  end

  def set_decision_timeline_context
    first_share_at = @quote.quote_shares.minimum(:created_at)
    latest_share_at = @quote.quote_shares.maximum(:created_at)
    first_view_at = @quote.quote_shares.minimum(:first_viewed_at) || @quote.viewed_at
    total_views = @quote.quote_shares.sum(&:view_count)
    last_view_at = @quote.quote_shares.maximum(:last_viewed_at) || @quote.viewed_at

    @quote_decision_recap = [
      {
        label: dt_t("recap.outcome.label"),
        value: decision_outcome_value,
        detail: decision_outcome_detail
      },
      {
        label: dt_t("recap.buyer_signal.label"),
        value: first_view_at.present? ? dt_t("recap.buyer_signal.viewed") : dt_t("recap.buyer_signal.no_view_yet"),
        detail: buyer_signal_detail(first_view_at, last_view_at, total_views)
      },
      {
        label: dt_t("recap.share_status.label"),
        value: first_share_at.present? ? dt_t("recap.share_status.links", count: @quote.quote_shares.size) : dt_t("recap.share_status.not_shared"),
        detail: latest_share_at.present? ? dt_t("recap.share_status.last_shared", time: format_in_user_time(latest_share_at, current_user)) : dt_t("recap.share_status.generate_link")
      },
      {
        label: dt_t("recap.pressure.label"),
        value: pressure_value,
        detail: pressure_detail
      }
    ]

    @quote_decision_timeline = [
      timeline_item(:created, @quote.issued_on&.to_time || @quote.created_at, dt_t("events.created.label"), dt_t("events.created.detail")),
      timeline_item(share_event_kind(latest_share_at), latest_share_at, share_event_label(latest_share_at), share_event_detail(latest_share_at)),
      timeline_item(:viewed, first_view_at, dt_t("events.viewed.label"), dt_t("events.viewed.detail")),
      timeline_item(:revision, @quote.changes_requested_at, dt_t("events.revision_requested.label"), revision_request_detail),
      timeline_item(:reopened, reopened_event_time, dt_t("events.reopened.label"), dt_t("events.reopened.detail")),
      timeline_item(:lost, lost_event_time, dt_t("events.lost.label"), dt_t("events.lost.detail")),
      timeline_item(:won, won_event_time, dt_t("events.won.label"), dt_t("events.won.detail")),
      timeline_item(:accepted, @quote.accepted_at, dt_t("events.accepted.label"), dt_t("events.accepted.detail")),
      timeline_item(:expired, expired_event_time, dt_t("events.expired.label"), dt_t("events.expired.detail"))
    ].compact.sort_by { |item| item[:at] }.reverse
  end

  def set_decision_review_context
    @quote_signal = QuoteSignalService.new(@quote).call
    @quote_decision_review = QuoteDecisionReviewService.new(
      quote: @quote,
      revision_diff: @revision_diff
    ).call
  end

  def timeline_item(kind, at, label, detail)
    return nil if at.blank?

    {
      kind: kind,
      at: at,
      label: label,
      detail: detail
    }
  end

  def revision_request_detail
    detail_parts = []
    detail_parts << @quote.request_reason.to_s.humanize if @quote.request_reason.present?
    detail_parts << @quote.changes_request_message if @quote.changes_request_message.present?
    detail_parts.presence&.join(" • ") || dt_t("revision_request.default_detail")
  end

  def expired_event_time
    return nil unless @quote.valid_until.present? && @quote.valid_until < Date.current

    @quote.valid_until.to_time.end_of_day
  end

  def lost_event_time
    return nil unless @quote.workflow_state == "lost"

    @quote.lost_at if @quote.respond_to?(:lost_at)
  end

  def won_event_time
    return nil unless @quote.status.to_s == "won"

    @quote.won_at if @quote.respond_to?(:won_at)
  end

  def reopened_event_time
    return nil unless reopened_pending?

    @quote.reopened_at
  end

  def decision_outcome_value
    return dt_t("outcome.accepted") if @quote.accepted_at.present?
    return dt_t("outcome.won") if @quote.status.to_s == "won"
    return dt_t("outcome.lost") if @quote.workflow_state == "lost"
    return dt_t("outcome.revision_requested") if @quote.changes_requested_at.present?
    return dt_t("outcome.expired") if expired_event_time.present?
    return dt_t("outcome.reopened") if reopened_pending?

    @quote.workflow_state.to_s.humanize
  end

  def decision_outcome_detail
    return dt_t("outcome_detail.accepted") if @quote.accepted_at.present?
    return dt_t("outcome_detail.won") if @quote.status.to_s == "won"
    return dt_t("outcome_detail.lost") if @quote.workflow_state == "lost"
    return revision_request_detail if @quote.changes_requested_at.present?
    return dt_t("outcome_detail.expired") if expired_event_time.present?
    return dt_t("outcome_detail.reopened") if reopened_pending?

    dt_t("outcome_detail.waiting")
  end

  def buyer_signal_detail(first_view_at, last_view_at, total_views)
    return dt_t("buyer_signal.no_view") if first_view_at.blank?

    detail = dt_t("buyer_signal.first_seen", time: format_in_user_time(first_view_at, current_user))
    if total_views.to_i > 1 && last_view_at.present?
      detail += " " + dt_t("buyer_signal.last_activity", time: format_in_user_time(last_view_at, current_user), count: total_views)
    elsif total_views.to_i == 1
      detail += " " + dt_t("buyer_signal.single_view")
    end
    detail
  end

  def pressure_value
    return dt_t("pressure.closed_won") if @quote.status.to_s == "won"
    return dt_t("pressure.reengage_later") if @quote.workflow_state == "lost"
    return dt_t("pressure.expired") if expired_event_time.present?
    return dt_t("pressure.needs_reshare") if reopened_pending?
    return dt_t("pressure.needs_revision") if @quote.changes_requested_at.present?
    return dt_t("pressure.days_left", count: @quote.expires_in_days) if @quote.expires_in_days.present? && @quote.expires_in_days <= 3

    dt_t("pressure.stable")
  end

  def pressure_detail
    return dt_t("pressure_detail.closed_won") if @quote.status.to_s == "won"
    return dt_t("pressure_detail.reengage_later") if @quote.workflow_state == "lost"
    return dt_t("pressure_detail.expired") if expired_event_time.present?
    return dt_t("pressure_detail.needs_reshare") if reopened_pending?
    return dt_t("pressure_detail.needs_revision") if @quote.changes_requested_at.present?
    return dt_t("pressure_detail.days_left") if @quote.expires_in_days.present? && @quote.expires_in_days <= 3

    dt_t("pressure_detail.stable")
  end

  def reopened_pending?
    return false if @quote.reopened_at.blank?
    return false unless @quote.workflow_state == "draft"

    latest_share_at = @quote.quote_shares.maximum(:created_at)
    latest_share_at.blank? || latest_share_at < @quote.reopened_at
  end

  def share_event_kind(latest_share_at)
    return :shared if latest_share_at.blank? || @quote.reopened_at.blank?
    return :reshared if latest_share_at > @quote.reopened_at

    :shared
  end

  def share_event_label(latest_share_at)
    return dt_t("events.reshared.label") if latest_share_at.present? && @quote.reopened_at.present? && latest_share_at > @quote.reopened_at

    dt_t("events.shared.label")
  end

  def share_event_detail(latest_share_at)
    return dt_t("events.reshared.detail") if latest_share_at.present? && @quote.reopened_at.present? && latest_share_at > @quote.reopened_at

    dt_t("events.shared.detail")
  end

  def dt_t(key, **options)
    I18n.t("quotes.logic.decision_timeline.#{key}", **options)
  end

  def format_in_user_time(value, user = current_user, format: "%Y-%m-%d %H:%M")
    helpers.format_in_user_time(value, user, format: format)
  end
end
