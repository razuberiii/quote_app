class QuotesController < ApplicationController
  require "base64"
  require "cgi"
  MAX_ITEM_IMAGE_UPLOADS_PER_REQUEST = 40
  MAX_ITEM_IMAGE_UPLOAD_BYTES_PER_REQUEST = 120.megabytes

  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate share send_reminder update_template reopen archive update_outcome_reason mark_sent mark_negotiating mark_outcome revert_to_sent undo_status_change public_preview create_pi]
  before_action :set_template, only: %i[show export_pdf export_xlsx share send_reminder update_template public_preview]
  before_action :set_form_products, only: %i[new edit create update duplicate]
  before_action :set_template_options, only: %i[new edit create update show duplicate update_template]
  before_action :set_quote_presets_payload, only: %i[new edit create update]
  around_action :with_quote_output_locale, only: %i[export_pdf export_xlsx]
  before_action :set_quote_document_locale, only: %i[show update_template]
  helper_method :quote_item_image_data_uri, :quote_logo_data_uri, :quote_watermark_data_uri, :quote_seller_signature_data_uri, :quote_seller_stamp_data_uri

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.not_archived.latest_versions
    redirect_to @customer
  end

  def all
    @quotes = current_user.company.quotes.includes(:customer).not_archived.order(updated_at: :desc)
  end

  def new
    @quote = @customer.quotes.new(currency: "USD", status: "draft", template: current_user.company.quote_template_or_default)
    prefill_business_terms_from_preset!(@quote)
    QuotePresetApplier.apply_advanced_defaults_if_enabled!(@quote, company: current_user.company)
    ensure_quote_item_row
  end

  def create
    unless current_user.can_create_quote?
      used = current_user.quote_count_for_limit
      redirect_to @customer, alert: t("quotes.flash.free_plan_limit_reached", used: used, limit: User::FREE_QUOTE_LIMIT) and return
    end

    normalize_detail_picture_uploads_param!
    @quote = @customer.quotes.new(quote_params)
    @quote.company = current_user.company
    @quote.status = "draft"
    @quote.template ||= current_user.company.quote_template_or_default
    apply_formal_closing_signature_overrides!(@quote)
    QuotePresetApplier.apply_advanced_defaults_if_enabled!(@quote, company: current_user.company)
    apply_quote_input_guardrails(@quote)

    if @quote.errors.none? && @quote.save
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
    set_related_pi_context
    set_superseded_context
    set_revision_compare_context
    @quote_decision_review = nil
    @quote_decision_timeline = []
    unless @quote.pi_document?
      set_decision_review_context
      set_decision_timeline_context
    end

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

    normalize_detail_picture_uploads_param!
    @quote.template ||= current_user.company.quote_template_or_default
    @quote.assign_attributes(quote_params)
    apply_formal_closing_signature_overrides!(@quote)
    QuotePresetApplier.apply_advanced_defaults_if_enabled!(@quote, company: current_user.company) unless @quote.pi_document?
    apply_quote_input_guardrails(@quote)

    if @quote.errors.none? && @quote.save
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

    if params[:debug].present?
      response.set_header("X-Quote-PDF-Engine", "debug-html")
      render template: "quotes/export_pdf", layout: "pdf", formats: [ :html ] and return
    end

    if Rails.env.test? && ENV["PDF_INTEGRATION"] != "1"
      filename = quote_export_filename(kind: kind, extension: "pdf", preview: false)
      if quote_pdf_engine == :wicked
        send_data "%PDF-1.4\n% Rubusoo test document\n", filename: filename, type: "application/pdf"
      else
        response.set_header("Content-Disposition", ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename))
        render template: "quotes/export_pdf", layout: "pdf", formats: [ :html ]
      end
      return
    end

    unless pdf_engine_available?
      if Rails.env.test?
        render template: "quotes/export_pdf", layout: "pdf", formats: [ :html ] and return
      end
      raise "No PDF renderer available (Grover/WickedPdf)."
    end

    pdf_binary = render_pdf_binary
    response.set_header("X-Quote-PDF-Engine", @pdf_render_engine_used.to_s.presence || "unknown")
    Rails.logger.info("Quote PDF engine used: #{@pdf_render_engine_used || 'unknown'}")

    mark_quote_as_sent_if_needed! unless params[:preview].present?

    preview_mode = params[:preview].present?
    export_filename = quote_export_filename(kind: kind, extension: "pdf", preview: preview_mode)
    send_data pdf_binary,
          filename: export_filename,
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
      export_filename = quote_export_filename(kind: kind, extension: "xlsx", preview: true)
      send_data payload,
                filename: export_filename,
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "inline"
      return
    end

    mark_quote_as_sent_if_needed!
    export_filename = quote_export_filename(kind: kind, extension: "xlsx", preview: false)

    send_data payload,
              filename: export_filename,
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
    @revision_summary = @template&.show_public_revision_summary? ? QuoteRevisionSummaryService.new(quote: @quote).call : nil
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

    source_quote = @quote
    @customer = source_quote.customer
    revision = source_quote.build_revision

    if revision.save
      redirect_to edit_quote_path(revision), notice: t("quotes.flash.revision_draft_created", quote_no: revision.quote_no)
      return
    end

    @quote = revision
    @source_quote = source_quote
    ensure_quote_item_row
    flash.now[:alert] = revision.errors.full_messages.to_sentence if revision.errors.any?
    render :new, formats: :html, status: :unprocessable_entity
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("Quote revision failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: t("quotes.flash.revision_schema_mismatch")
  end

  def create_pi
    unless @quote.latest_revision_for_quote_no? && !@quote.archived? && !@quote.pi_document?
      redirect_to quote_path(@quote), alert: t("quotes.flash.pi_generation_not_available") and return
    end

    existing_pi = existing_pi_quote_for(@quote)
    if existing_pi.present?
      redirect_to quote_path(existing_pi, doc: "pi", document_kind: "pi"), notice: t("quotes.flash.pi_opened_existing")
      return
    end

    pi_quote = PiFromQuoteBuilder.new(@quote, actor: current_user, pi_options: pi_options_params.to_h).call
    redirect_to quote_path(pi_quote, doc: "pi", document_kind: "pi"), notice: t("quotes.flash.pi_created")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to quote_path(@quote), alert: t("quotes.flash.pi_create_failed", errors: e.record.errors.full_messages.to_sentence)
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
    @quote = current_user.company.quotes.not_archived.includes({ quote_items: [ :product, { item_image_attachment: :blob } ] }, :customer, :template, :quote_shares).find(params[:id])
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
    return pi_quote_params if @quote&.pi_document?

    permitted = params.require(:quote).permit(
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
      :advanced_mode,
      :template_id,
      :seller_signature_image,
      :seller_stamp_image,
      advanced_trade_terms: {},
      advanced_logistics: {},
      advanced_visibility: {},
      configuration_block: {},
      detail_pictures_block: {},
      formal_closing_block: {},
      container_loading_block: {},
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity, :item_type, :specifications_text, :addon_charges_text, :item_image, :item_image_blob_id, :remove_item_image, :_destroy ]
    )
    raw_quote = params[:quote]
    if raw_quote.respond_to?(:to_unsafe_h)
      raw_hash = raw_quote.to_unsafe_h
      permitted[:configuration_block] = raw_hash["configuration_block"] if raw_hash.key?("configuration_block")
      permitted[:detail_pictures_block] = raw_hash["detail_pictures_block"] if raw_hash.key?("detail_pictures_block")
      if Quote.column_names.include?("formal_closing_block")
        permitted[:formal_closing_block] = raw_hash["formal_closing_block"] if raw_hash.key?("formal_closing_block")
      else
        permitted.delete(:formal_closing_block)
      end
      if Quote.column_names.include?("container_loading_block")
        permitted[:container_loading_block] = raw_hash["container_loading_block"] if raw_hash.key?("container_loading_block")
      else
        permitted.delete(:container_loading_block)
      end
    end
    permitted.delete(:container_loading_block) unless Quote.column_names.include?("container_loading_block")
    permitted.delete(:formal_closing_block) unless Quote.column_names.include?("formal_closing_block")
    permitted
  end

  def pi_quote_params
    permitted = params.require(:quote).permit(
      :issued_on,
      :valid_until,
      :payment_term,
      :trade_term,
      :custom_title,
      :notes,
      :terms_text,
      :legal_disclaimer,
      :delivery_notes,
      :scope_of_supply,
      :template_id
    )
    raw_quote = params[:quote]
    if raw_quote.respond_to?(:to_unsafe_h) && Quote.column_names.include?("formal_closing_block")
      raw_hash = raw_quote.to_unsafe_h
      block = raw_hash["formal_closing_block"]
      if block.is_a?(Hash)
        allowed_keys = %w[
          pi_number
          payment_term
          trade_term
          delivery_time
          bank_route
          beneficiary_details
          remittance_note
          buyer_signature_line_enabled
        ]
        permitted[:formal_closing_block] = block.slice(*allowed_keys)
      end
    end
    permitted
  end

  def pi_options_params
    params.fetch(:pi_options, {}).permit(
      :pi_number,
      :issued_on,
      :payment_term,
      :trade_term,
      :delivery_time,
      :bank_route,
      :beneficiary_details,
      :remittance_note,
      :buyer_signature_line_enabled
    )
  end

  def mark_won_params
    params.require(:quote).permit(:win_reason, :win_reason_detail, :final_amount)
  end

  def mark_lost_params
    params.require(:quote).permit(:loss_reason, :loss_reason_detail)
  end

  def set_form_products
    @products = current_user.company.products.with_attached_image.with_attached_gallery_images.order(:name)
  end

  def set_template_options
    @template_options = current_user.company.quote_templates.ordered
  end

  def ensure_quote_item_row
    return if @quote.quote_items.reject(&:marked_for_destruction?).any?

    @quote.quote_items.build
  end

  def prefill_business_terms_from_preset!(quote)
    QuotePresetApplier.apply_business_terms_default!(quote, company: current_user.company)
  end

  def set_quote_presets_payload
    presets = current_user.company.quote_presets.ordered
    @quote_presets_by_module = QuotePreset::MODULE_KEYS.index_with do |module_key|
      presets
        .select { |preset| preset.module_key == module_key }
        .map do |preset|
          payload = preset.payload_data
          if module_key == "formal_closing"
            payload = payload.merge(
              "seller_signature_image_url" => (Rails.application.routes.url_helpers.rails_blob_path(preset.seller_signature_image, only_path: true) if preset.seller_signature_image.attached?),
              "seller_signature_blob_signed_id" => (preset.seller_signature_image.blob.signed_id if preset.seller_signature_image.attached?),
              "seller_stamp_image_url" => (Rails.application.routes.url_helpers.rails_blob_path(preset.seller_stamp_image, only_path: true) if preset.seller_stamp_image.attached?),
              "seller_stamp_blob_signed_id" => (preset.seller_stamp_image.blob.signed_id if preset.seller_stamp_image.attached?)
            )
          end
          { id: preset.id, name: preset.name, payload: payload }
        end
    end
    @quote_preset_master = current_user.company.quote_preset_master
  end

  def apply_formal_closing_signature_overrides!(quote)
    source = params[:quote]
    return unless source.respond_to?(:[])

    if source[:remove_seller_signature_image].to_s == "1"
      quote.seller_signature_image.purge if quote.seller_signature_image.attached?
    elsif source[:seller_signature_image].blank?
      signed_id = source[:seller_signature_image_blob_signed_id].to_s
      quote.seller_signature_image.attach(signed_id) if signed_id.present?
    end

    if source[:remove_seller_stamp_image].to_s == "1"
      quote.seller_stamp_image.purge if quote.seller_stamp_image.attached?
    elsif source[:seller_stamp_image].blank?
      signed_id = source[:seller_stamp_image_blob_signed_id].to_s
      quote.seller_stamp_image.attach(signed_id) if signed_id.present?
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    # Ignore invalid signed ids and keep current attachment state.
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
    attachment = item.effective_image_attachment
    return nil if attachment.blank?

    blob = attachment.blob
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

  def quote_pdf_engine
    configured = ENV.fetch("QUOTE_PDF_ENGINE", Rails.configuration.x.quote_pdf.engine).to_s.strip.downcase
    configured == "wicked" ? :wicked : :grover
  end

  def pdf_engine_available?
    use_grover_renderer? || use_wicked_pdf_renderer?(wicked_pdf_client)
  end

  def render_pdf_binary
    html = render_pdf_html
    footer_line = quote_pdf_footer_line

    case quote_pdf_engine
    when :wicked
      @pdf_render_engine_used = "wicked"
      render_pdf_with_wicked(html: html, footer_line: footer_line)
    else
      begin
        @pdf_render_engine_used = "grover"
        render_pdf_with_grover(html: html, footer_line: footer_line)
      rescue StandardError => e
        Rails.logger.warn("Grover PDF render failed, fallback to WickedPdf. #{e.class}: #{e.message}")
        @pdf_render_engine_used = "wicked_fallback_from_grover"
        render_pdf_with_wicked(html: html, footer_line: footer_line)
      end
    end
  rescue StandardError => e
    raise unless use_wicked_pdf_renderer?(wicked_pdf_client)

    Rails.logger.warn("Primary PDF render failed, retrying with WickedPdf. #{e.class}: #{e.message}")
    @pdf_render_engine_used = "wicked_fallback_secondary"
    render_pdf_with_wicked(html: render_pdf_html, footer_line: quote_pdf_footer_line)
  end

  def render_pdf_html
    render_to_string(
      template: "quotes/export_pdf",
      formats: [ :html ],
      layout: "pdf"
    )
  end

  def quote_pdf_footer_line
    address_text = @quote.company.address.to_s.squish
    compact_location = quote_pdf_compact_location(address_text)
    [
      @quote.company.name,
      compact_location.presence || address_text,
      @quote.company.email,
      @quote.company.website
    ].map { |v| v.to_s.squish.presence }.compact.join(" · ")
  end

  def render_pdf_with_wicked(html:, footer_line:)
    pdf_client = wicked_pdf_client
    unless use_wicked_pdf_renderer?(pdf_client)
      raise "WickedPdf unavailable."
    end

    pdf_options = {
      encoding: "UTF-8",
      page_size: "A4",
      margin: { top: 10, bottom: 16, left: 10, right: 10 },
      print_media_type: true,
      enable_local_file_access: true
    }
    if footer_line.present?
      pdf_options[:footer] = {
        center: footer_line,
        line: true,
        spacing: 1.5,
        font_size: 8
      }
    end

    pdf_client.new.pdf_from_string(html, pdf_options)
  end

  def use_grover_renderer?
    return false unless grover_client

    true
  end

  def grover_client
    require "grover" unless defined?(::Grover)
    return nil unless defined?(::Grover)

    ::Grover
  rescue LoadError
    nil
  end

  def render_pdf_with_grover(html:, footer_line:)
    client = grover_client
    raise "Grover unavailable." unless client

    footer_html = if footer_line.present?
      "<div style=\"width:100%; border-top:1px solid #d9d9d9; font-family:'Segoe UI','Noto Sans',Arial,sans-serif; font-weight:400; font-size:7.5pt; color:#3f3f3f; text-align:center; line-height:1.12; letter-spacing:0; padding-top:2px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;\">#{CGI.escapeHTML(footer_line)}</div>"
    else
      "<div></div>"
    end

    grover_options = {
      format: "A4",
      print_background: true,
      prefer_css_page_size: false,
      emulate_media: "print",
      margin: { top: "10mm", right: "10mm", bottom: "16mm", left: "10mm" },
      display_header_footer: true,
      header_template: "<div></div>",
      footer_template: footer_html
    }
    chrome_bin = quote_pdf_chrome_bin
    grover_options[:executable_path] = chrome_bin if chrome_bin.present?
    if ActiveModel::Type::Boolean.new.cast(ENV.fetch("GROVER_NO_SANDBOX", "false"))
      grover_options[:launch_args] = [ "--no-sandbox", "--disable-dev-shm-usage" ]
    end

    client.new(html, grover_options).to_pdf
  end

  def quote_pdf_chrome_bin
    env_path = ENV["CHROME_BIN"].to_s.strip
    return env_path if env_path.present?

    candidates = [
      "C:/Program Files/Google/Chrome/Application/chrome.exe",
      "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/usr/bin/google-chrome"
    ]

    candidates.find { |path| File.exist?(path) }
  end

  def quote_seller_signature_data_uri(quote)
    quote_attachment_data_uri(quote&.seller_signature_image)
  end

  def quote_seller_stamp_data_uri(quote)
    quote_attachment_data_uri(quote&.seller_stamp_image)
  end

  def quote_attachment_data_uri(attachment)
    return nil unless attachment.respond_to?(:attached?) && attachment.attached?

    blob = attachment.blob
    payload = blob.download
    encoded = Base64.strict_encode64(payload)
    "data:#{blob.content_type};base64,#{encoded}"
  rescue StandardError
    nil
  end

  def quote_pdf_compact_location(address_text)
    text = address_text.to_s.squish
    return nil if text.blank?

    parts = text.split(",").map(&:strip).reject(&:blank?)
    return nil if parts.length < 2

    "#{parts[-2]}, #{parts[-1]}"
  end

  def quote_export_filename(kind:, extension:, preview:)
    base_name = quote_export_base_name
    suffix = preview ? "_preview" : ""
    "#{kind}_#{base_name}#{suffix}.#{extension}"
  end

  def quote_export_base_name
    preferred = @quote.custom_title.to_s.squish
    item_name = @quote.quote_items.ordered.first&.yield_self do |item|
      item.product&.name.to_s.squish.presence || item.description.to_s.squish.presence
    end
    fallback = @quote.quote_no.to_s.squish.presence || item_name.presence || "quote"
    raw_name = preferred.presence || item_name.presence || fallback

    sanitized = raw_name.gsub(/[\\\/:*?"<>|]+/, " ").squish
    sanitized.presence || fallback
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
      currency: @quote.currency,
      current_revision: @quote.revision_number,
      previous_revision: @previous_revision_quote.revision_number
    ).call
  end

  def apply_quote_input_guardrails(quote)
    item_attrs = extract_quote_item_attribute_rows
    if item_attrs.length > Quote::MAX_QUOTE_ITEMS_COUNT
      quote.errors.add(:quote_items, "can include up to #{Quote::MAX_QUOTE_ITEMS_COUNT} items")
    end

    upload_rows = item_attrs.filter_map do |attrs|
      image_file = attrs["item_image"] || attrs[:item_image]
      next if image_file.blank?

      image_file
    end

    if upload_rows.length > MAX_ITEM_IMAGE_UPLOADS_PER_REQUEST
      quote.errors.add(:base, "Too many images in one request (maximum is #{MAX_ITEM_IMAGE_UPLOADS_PER_REQUEST}).")
    end

    total_upload_size = upload_rows.sum { |file| file.respond_to?(:size) ? file.size.to_i : 0 }
    if total_upload_size > MAX_ITEM_IMAGE_UPLOAD_BYTES_PER_REQUEST
      max_mb = (MAX_ITEM_IMAGE_UPLOAD_BYTES_PER_REQUEST / 1.megabyte).to_i
      quote.errors.add(:base, "Total image upload size is too large (maximum is #{max_mb}MB per request).")
    end

    detail_items = extract_detail_picture_items
    if detail_items.length > Quote::MAX_DETAIL_PICTURES_ITEMS
      quote.errors.add(:detail_pictures_block, "items exceed limit (#{Quote::MAX_DETAIL_PICTURES_ITEMS})")
    end

    detail_uploads = detail_items.filter_map do |item|
      item_hash =
        if item.respond_to?(:to_unsafe_h)
          item.to_unsafe_h
        elsif item.is_a?(Hash)
          item
        else
          nil
        end
      next if item_hash.blank?

      item_hash["upload"] || item_hash[:upload]
    end
    total_detail_upload_size = detail_uploads.sum { |file| file.respond_to?(:size) ? file.size.to_i : 0 }
    batch_detail_uploads = extract_detail_picture_batch_uploads
    total_detail_upload_size += batch_detail_uploads.sum { |file| file.respond_to?(:size) ? file.size.to_i : 0 }
    if total_detail_upload_size > MAX_ITEM_IMAGE_UPLOAD_BYTES_PER_REQUEST
      max_mb = (MAX_ITEM_IMAGE_UPLOAD_BYTES_PER_REQUEST / 1.megabyte).to_i
      quote.errors.add(:detail_pictures_block, "total upload size is too large (maximum is #{max_mb}MB per request)")
    end

    total_detail_count = detail_items.length + batch_detail_uploads.length
    if total_detail_count > Quote::MAX_DETAIL_PICTURES_ITEMS
      quote.errors.add(:detail_pictures_block, "items exceed limit (#{Quote::MAX_DETAIL_PICTURES_ITEMS})")
    end

    configuration_rows = extract_configuration_rows
    if configuration_rows.length > Quote::MAX_CONFIGURATION_BLOCK_ROWS
      quote.errors.add(:configuration_block, "rows exceed limit (#{Quote::MAX_CONFIGURATION_BLOCK_ROWS})")
    end

    container_loading_rows = extract_container_loading_rows
    if container_loading_rows.length > Quote::MAX_CONTAINER_LOADING_ROWS
      quote.errors.add(:container_loading_block, "rows exceed limit (#{Quote::MAX_CONTAINER_LOADING_ROWS})")
    end
  end

  def extract_quote_item_attribute_rows
    raw = params.dig(:quote, :quote_items_attributes)
    return [] if raw.blank?

    if raw.is_a?(Array)
      raw
    elsif raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h.values
    elsif raw.is_a?(Hash)
      raw.values
    else
      []
    end
  end

  def extract_detail_picture_items
    block = params.dig(:quote, :detail_pictures_block)
    return [] if block.blank?

    source = if block.respond_to?(:to_unsafe_h)
      block.to_unsafe_h
    elsif block.is_a?(Hash)
      block
    else
      {}
    end
    items = source["items"] || source[:items]
    if items.is_a?(Array)
      items
    elsif items.is_a?(Hash)
      items.values
    else
      []
    end
  end

  def extract_detail_picture_batch_uploads
    raw = params.dig(:quote, :detail_pictures_batch_uploads)
    return [] if raw.blank?

    if raw.is_a?(Array)
      raw
    elsif raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h.values
    elsif raw.is_a?(Hash)
      raw.values
    else
      []
    end
  end

  def extract_detail_picture_batch_captions
    raw = params.dig(:quote, :detail_pictures_batch_captions)
    return [] if raw.blank?

    if raw.is_a?(Array)
      raw
    elsif raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h.values
    elsif raw.is_a?(Hash)
      raw.values
    else
      []
    end
  end

  def extract_configuration_rows
    block = params.dig(:quote, :configuration_block)
    return [] if block.blank?

    source = if block.respond_to?(:to_unsafe_h)
      block.to_unsafe_h
    elsif block.is_a?(Hash)
      block
    else
      {}
    end
    rows = source["rows"] || source[:rows]
    if rows.is_a?(Array)
      rows
    elsif rows.is_a?(Hash)
      rows.values
    else
      []
    end
  end

  def extract_container_loading_rows
    block = params.dig(:quote, :container_loading_block)
    return [] if block.blank?

    source = if block.respond_to?(:to_unsafe_h)
      block.to_unsafe_h
    elsif block.is_a?(Hash)
      block
    else
      {}
    end
    rows = source["rows"] || source[:rows]
    if rows.is_a?(Array)
      rows
    elsif rows.is_a?(Hash)
      rows.values
    else
      []
    end
  end

  def normalize_detail_picture_uploads_param!
    detail_items = extract_detail_picture_items
    batch_uploads = extract_detail_picture_batch_uploads
    batch_captions = extract_detail_picture_batch_captions

    detail_items.each do |item|
      item_hash =
        if item.respond_to?(:to_unsafe_h)
          item.to_unsafe_h
        elsif item.is_a?(Hash)
          item
        else
          nil
        end
      next if item_hash.blank?

      upload = item_hash["upload"] || item_hash[:upload]
      next if upload.blank?

      content_type = upload.respond_to?(:content_type) ? upload.content_type.to_s : ""
      size = upload.respond_to?(:size) ? upload.size.to_i : 0
      next unless content_type.start_with?("image/")
      next if size <= 0 || size > QuoteItem::MAX_IMAGE_SIZE

      io = if upload.respond_to?(:tempfile) && upload.tempfile.present?
        upload.tempfile.tap(&:rewind)
      else
        upload
      end
      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: upload.respond_to?(:original_filename) ? upload.original_filename.to_s : "quote-detail-picture",
        content_type: content_type
      )

      item_hash["image_blob_id"] = blob.id.to_s
      item_hash["source"] = "quote_upload"
      item_hash.delete("upload")
      item_hash.delete(:upload)

      if item.respond_to?(:to_unsafe_h)
        item.clear
        item_hash.each { |k, v| item[k] = v }
      end
    end

    return if batch_uploads.blank?

    raw_quote = params[:quote]
    return unless raw_quote.respond_to?(:to_unsafe_h) || raw_quote.is_a?(Hash)

    quote_hash = raw_quote.respond_to?(:to_unsafe_h) ? raw_quote.to_unsafe_h : raw_quote
    block = quote_hash["detail_pictures_block"] || quote_hash[:detail_pictures_block]
    block ||= {}
    items = block["items"] || block[:items]
    normalized_items =
      if items.is_a?(Array)
        items
      elsif items.is_a?(Hash)
        items.values
      else
        []
      end

    batch_uploads.each_with_index do |upload, idx|
      next if upload.blank?

      content_type = upload.respond_to?(:content_type) ? upload.content_type.to_s : ""
      size = upload.respond_to?(:size) ? upload.size.to_i : 0
      next unless content_type.start_with?("image/")
      next if size <= 0 || size > QuoteItem::MAX_IMAGE_SIZE

      io = if upload.respond_to?(:tempfile) && upload.tempfile.present?
        upload.tempfile.tap(&:rewind)
      else
        upload
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: upload.respond_to?(:original_filename) ? upload.original_filename.to_s : "quote-detail-picture",
        content_type: content_type
      )

      normalized_items << {
        "image_blob_id" => blob.id.to_s,
        "source" => "quote_upload",
        "caption" => batch_captions[idx].to_s.squish,
        "position" => normalized_items.size + 1
      }
    end

    block["enabled"] = true if normalized_items.any?
    block["items"] = normalized_items
    quote_hash["detail_pictures_block"] = block

    if raw_quote.respond_to?(:to_unsafe_h)
      raw_quote["detail_pictures_block"] = block
      raw_quote.delete("detail_pictures_batch_uploads")
      raw_quote.delete(:detail_pictures_batch_uploads)
      raw_quote.delete("detail_pictures_batch_captions")
      raw_quote.delete(:detail_pictures_batch_captions)
    end
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

  def set_related_pi_context
    unless Quote.column_names.include?("source_quote_id")
      @derived_pi_quotes = []
      @derived_pi_quote = nil
      @source_quote_for_pi = nil
      return
    end

    @derived_pi_quote = @quote.derived_quotes.includes(:template).order(created_at: :desc).find(&:pi_document?)
    @derived_pi_quotes = @derived_pi_quote.present? ? [ @derived_pi_quote ] : []
    @source_quote_for_pi = @quote.source_quote if @quote.pi_document?
  end

  def existing_pi_quote_for(source_quote)
    return nil unless Quote.column_names.include?("source_quote_id")

    source_quote.derived_quotes.order(created_at: :desc).find(&:pi_document?)
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
