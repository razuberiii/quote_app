class QuotesController < ApplicationController
  require "base64"

  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate duplicate_and_reprice share send_reminder update_template reopen archive]
  before_action :set_template, only: %i[show export_pdf export_xlsx share send_reminder update_template]
  before_action :set_form_products, only: %i[new edit create update duplicate duplicate_and_reprice]
  before_action :set_template_options, only: %i[new edit create update show duplicate duplicate_and_reprice update_template]
  helper_method :quote_item_image_data_uri, :quote_logo_data_uri, :quote_watermark_data_uri

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.not_archived.latest_versions
    redirect_to @customer
  end

  def new
    @quote = @customer.quotes.new(currency: "USD", status: "draft", template: current_user.company.quote_template_or_default)
    ensure_quote_item_row
  end

  def create
    unless current_user.can_create_quote?
      used = current_user.quote_count_for_limit
      redirect_to @customer, alert: "Free plan limit reached: #{used}/#{User::FREE_QUOTE_LIMIT} company quotes used." and return
    end

    @quote = @customer.quotes.new(quote_params)
    @quote.company = current_user.company
    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.save
      redirect_to @quote, status: :see_other
    else
      ensure_quote_item_row
      render :new, status: :unprocessable_entity
    end
  end

  def show
    request.format = :html if request.format.turbo_stream? && params[:format] != "turbo_stream"

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
      redirect_to quote_path(@quote), alert: "This revision is read-only in the current state." and return
    end
    ensure_quote_item_row
  end

  def update
    unless @quote.can_edit_revision?
      redirect_to quote_path(@quote), alert: "This revision is read-only in the current state." and return
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
      redirect_to quote_path(@quote), alert: "Template cannot be changed in the current state." and return
    end

    requested_template_id = params[:template_id].presence
    template = current_user.company.quote_templates.find_by(id: requested_template_id)
    template ||= current_user.company.quote_template_or_default
    template = current_user.company.quote_templates.order(:created_at).first if template&.new_record?
    unless template
      redirect_to quote_path(@quote), alert: "No template available. Please create a quote template first." and return
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
      format.json { render json: { message: "Template updated" } }
      format.html { redirect_to quote_path(@quote, doc: @document_kind), notice: "Template updated" }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to quote_path(@quote), alert: "Template not found. Reverted to current template."
  end

  def destroy
    unless @quote.can_delete_quote_family?
      redirect_to quote_path(@quote), alert: "Only the latest active revision can delete the whole quote thread." and return
    end

    deletion_time = Time.current
    family_scope = current_user.company.quotes.not_archived.where(quote_no: @quote.quote_no)
    affected_product_ids = family_scope.joins(:quote_items).where.not(quote_items: { product_id: nil }).distinct.pluck("quote_items.product_id")
    family_scope.update_all(status: "expired", deleted_at: deletion_time, updated_at: deletion_time)
    current_user.company.quote_shares.where(quote_id: family_scope.select(:id)).update_all(expires_at: deletion_time, updated_at: deletion_time)
    ProductIntelligenceRefresher.refresh_products(affected_product_ids)

    redirect_to @quote.customer, status: :see_other, notice: "Quote thread #{@quote.quote_no} deleted. Public links now show as expired."
  end

  def archive
    unless Quote.column_names.include?("archived_at")
      redirect_to quote_path(@quote), alert: "Archive feature is not ready. Please run database migrations on the server." and return
    end

    unless @quote.can_archive_revision?
      redirect_to quote_path(@quote), alert: "Only non-latest revisions can be archived." and return
    end

    @quote.update!(archived_at: Time.current)
    latest = current_user.company.quotes.not_archived.where(quote_no: @quote.quote_no).order(revision_number: :desc).first
    redirect_target = latest || @quote.customer
    redirect_to redirect_target, status: :see_other, notice: "Revision V#{@quote.revision_number} archived from history."
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

    send_data pdf_binary,
              filename: "#{kind}_#{@quote.quote_no}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  rescue StandardError => e
    Rails.logger.error("Quote PDF export failed: #{e.class} #{e.message}; wkhtmltopdf=#{configured_wkhtmltopdf_path.inspect}")
    redirect_to quote_path(@quote), alert: "PDF export failed on server. Please verify wkhtmltopdf is installed and configured."
  end

  def export_xlsx
    kind = resolved_document_kind
    exporter = quote_exporter(kind, @template)
    package = exporter.to_xlsx
    payload = package.to_stream.read
    exporter.cleanup_tempfiles!

    send_data payload,
              filename: "#{kind}_#{@quote.quote_no}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  rescue StandardError
    exporter&.cleanup_tempfiles!
    raise
  end

  def duplicate
    unless @quote.can_create_new_revision?
      redirect_to quote_path(@quote), alert: "New revision is not available for the current quote state." and return
    end

    @customer = @quote.customer
    @quote = @quote.build_revision
    ensure_quote_item_row
    flash.now[:notice] = "Revision draft created from quote #{@quote.quote_no}. Edit and save to create a new version."
    render :new, formats: :html
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("Quote revision failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: "Revision failed due to schema mismatch. Please run database migrations on the server."
  end

  def duplicate_and_reprice
    unless @quote.can_copy_and_reprice?
      redirect_to quote_path(@quote), alert: "Copy & Reprice is not available for the current quote state." and return
    end

    revision = @quote.build_revision
    revision.status = "draft" if revision.status.blank? || revision.status == "expired"
    revision.save!
    redirect_to edit_quote_path(revision), status: :see_other, notice: "Revision V#{revision.revision_number} created. Update pricing and share."
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Quote duplicate_and_reprice failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: "Unable to create revision: #{e.record.errors.full_messages.to_sentence}"
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("Quote duplicate_and_reprice failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: "Revision failed due to schema mismatch. Please run database migrations on the server."
  end

  def share
    unless @quote.can_share_publicly?
      redirect_to quote_path(@quote), alert: "Sharing is disabled for the current quote state." and return
    end

    publish_result = QuoteSharePublisher.new(
      @quote,
      document_kind: resolved_document_kind,
      url_options: { host: request.host, port: request.optional_port, protocol: request.protocol.delete_suffix("://") }
    ).call
    share_url = publish_result.url

    respond_to do |format|
      format.json { render json: { url: share_url, token: publish_result.share.token } }
      format.html { redirect_to share_url }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Quote share failed: #{e.class} #{e.message}")
    respond_to do |format|
      format.json { render json: { message: "Unable to create public share link: #{e.record.errors.full_messages.to_sentence}" }, status: :unprocessable_entity }
      format.html { redirect_to quote_path(@quote), alert: "Unable to create public share link: #{e.record.errors.full_messages.to_sentence}" }
    end
  rescue StandardError => e
    Rails.logger.error("Quote share failed: #{e.class} #{e.message}")
    respond_to do |format|
      format.json { render json: { message: "Unable to create public share link right now. Please try again." }, status: :internal_server_error }
      format.html { redirect_to quote_path(@quote), alert: "Unable to create public share link right now. Please try again." }
    end
  end

  def send_reminder
    unless @quote.can_send_reminder?
      redirect_to quote_path(@quote), alert: "Reminder is not available for this quote." and return
    end

    unless verify_turnstile_for_html!(
      token: params[:cf_turnstile_response],
      on_missing: -> { redirect_to quote_path(@quote), alert: "Please complete verification before sending a reminder." },
      on_failed: -> { redirect_to quote_path(@quote), alert: "Verification failed. Please try again." }
    )
      return
    end

    QuoteReminderSender.new(
      @quote,
      document_kind: resolved_document_kind,
      url_options: { host: request.host, port: request.optional_port, protocol: request.protocol.delete_suffix("://") }
    ).call
    redirect_to quote_path(@quote), status: :see_other, notice: "Reminder email sent. Next reminder will be available in 12 hours unless the quote gets viewed first."
  rescue StandardError => e
    Rails.logger.error("Quote reminder failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), status: :see_other, alert: "Unable to send reminder right now."
  end

  def reopen
    unless @quote.can_reopen?
      redirect_to quote_path(@quote), alert: "Reopen is not available for the current quote state." and return
    end

    @quote.update_columns(
      status: "draft",
      accepted_at: nil,
      changes_requested_at: nil,
      changes_request_message: nil,
      reopened_at: Time.current,
      updated_at: Time.current
    )
    redirect_to quote_path(@quote), status: :see_other, notice: "Quote reopened for editing."
  end

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:customer_id])
  end

  def set_quote
    Quote.expire_overdue_for_company!(current_user.company_id)
    @quote = current_user.company.quotes.not_archived.includes({ quote_items: :product }, :customer, :template, :quote_shares).find(params[:id])
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
      :template_id,
      quote_items_attributes: [ :id, :product_id, :description, :unit_price, :quantity, :specifications_text, :addon_charges_text, :_destroy ]
    )
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

  def quote_exporter(kind = "quote", template = nil)
    require Rails.root.join("app/services/quote_exporter").to_s unless defined?(::QuoteExporter)
    template ||= @template
    @quote_exporters ||= {}
    cache_key = "#{kind}-#{template&.id || 'default'}"
    @quote_exporters[cache_key] ||= ::QuoteExporter.new(@quote, template: template, document_kind: kind)
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
    return false if windows_platform?

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

  def windows_platform?
    RbConfig::CONFIG["host_os"].to_s.match?(/mswin|mingw|cygwin/i)
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
        label: "Outcome",
        value: decision_outcome_value,
        detail: decision_outcome_detail
      },
      {
        label: "Buyer Signal",
        value: first_view_at.present? ? "Viewed" : "No view yet",
        detail: buyer_signal_detail(first_view_at, last_view_at, total_views)
      },
      {
        label: "Share Status",
        value: first_share_at.present? ? "#{@quote.quote_shares.size} link#{'s' unless @quote.quote_shares.size == 1}" : "Not shared",
        detail: latest_share_at.present? ? "Last shared #{format_in_user_time(latest_share_at, current_user)}." : "Generate a public link to start engagement."
      },
      {
        label: "Pressure",
        value: pressure_value,
        detail: pressure_detail
      }
    ]

    @quote_decision_timeline = [
      timeline_item(:created, @quote.issued_on&.to_time || @quote.created_at, "Created", "Quote version prepared."),
      timeline_item(share_event_kind(latest_share_at), latest_share_at, share_event_label(latest_share_at), share_event_detail(latest_share_at)),
      timeline_item(:viewed, first_view_at, "Viewed", "Buyer opened the quote for the first time."),
      timeline_item(:revision, @quote.changes_requested_at, "Revision Requested", revision_request_detail),
      timeline_item(:reopened, reopened_event_time, "Reopened", "Quote moved back to draft for editing."),
      timeline_item(:lost, lost_event_time, "Lost", "Buyer did not move forward with this revision."),
      timeline_item(:won, won_event_time, "Won", "Quote marked as commercially won."),
      timeline_item(:accepted, @quote.accepted_at, "Accepted", "Buyer confirmed the quote."),
      timeline_item(:expired, expired_event_time, "Expired", "Validity window ended without closure.")
    ].compact.sort_by { |item| item[:at] }.reverse
  end

  def set_decision_review_context
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
    detail_parts.presence&.join(" • ") || "Buyer asked for an update."
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
    return "Accepted" if @quote.accepted_at.present?
    return "Won" if @quote.status.to_s == "won"
    return "Lost" if @quote.workflow_state == "lost"
    return "Revision Requested" if @quote.changes_requested_at.present?
    return "Expired" if expired_event_time.present?
    return "Reopened" if reopened_pending?

    @quote.workflow_state.to_s.humanize
  end

  def decision_outcome_detail
    return "Buyer accepted this revision." if @quote.accepted_at.present?
    return "Quote marked as commercially won." if @quote.status.to_s == "won"
    return "Buyer chose not to proceed with this revision." if @quote.workflow_state == "lost"
    return revision_request_detail if @quote.changes_requested_at.present?
    return "Validity window closed without a decision." if expired_event_time.present?
    return "Quote is back in draft for rework." if reopened_pending?

    "Waiting for buyer movement on this revision."
  end

  def buyer_signal_detail(first_view_at, last_view_at, total_views)
    return "No buyer view recorded yet." if first_view_at.blank?

    detail = "First seen #{format_in_user_time(first_view_at, current_user)}."
    if total_views.to_i > 1 && last_view_at.present?
      detail += " Last activity #{format_in_user_time(last_view_at, current_user)} (#{total_views} views)."
    elsif total_views.to_i == 1
      detail += " Single recorded view."
    end
    detail
  end

  def pressure_value
    return "Closed won" if @quote.status.to_s == "won"
    return "Re-engage later" if @quote.workflow_state == "lost"
    return "Expired" if expired_event_time.present?
    return "Needs reshare" if reopened_pending?
    return "Needs revision" if @quote.changes_requested_at.present?
    return "#{@quote.expires_in_days}d left" if @quote.expires_in_days.present? && @quote.expires_in_days <= 3

    "Stable"
  end

  def pressure_detail
    return "Track handoff, delivery, or renewal timing." if @quote.status.to_s == "won"
    return "Create a new revision if the buyer comes back." if @quote.workflow_state == "lost"
    return "Follow up with a new revision or close the thread." if expired_event_time.present?
    return "Generate a fresh public link for the reopened revision." if reopened_pending?
    return "Buyer requested changes on this revision." if @quote.changes_requested_at.present?
    return "Act before validity runs out." if @quote.expires_in_days.present? && @quote.expires_in_days <= 3

    "No immediate expiry or revision pressure."
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
    return "Reshared" if latest_share_at.present? && @quote.reopened_at.present? && latest_share_at > @quote.reopened_at

    "Shared"
  end

  def share_event_detail(latest_share_at)
    return "Fresh public quote link generated after reopening." if latest_share_at.present? && @quote.reopened_at.present? && latest_share_at > @quote.reopened_at

    "Public quote link generated and ready to send."
  end

  def format_in_user_time(value, user = current_user, format: "%Y-%m-%d %H:%M")
    helpers.format_in_user_time(value, user, format: format)
  end
end
