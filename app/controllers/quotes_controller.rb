class QuotesController < ApplicationController
  require "base64"

  before_action :set_customer, only: %i[new create]
  before_action :set_quote, only: %i[show edit update destroy export_pdf export_xlsx duplicate duplicate_and_reprice share update_template]
  before_action :set_template, only: %i[show export_pdf export_xlsx share update_template]
  before_action :set_form_products, only: %i[new edit create update duplicate duplicate_and_reprice]
  before_action :set_template_options, only: %i[new edit create update show duplicate duplicate_and_reprice update_template]
  helper_method :quote_item_image_data_uri, :quote_logo_data_uri

  def index
    @customer = current_user.company.customers.find(params[:customer_id])
    @quotes = @customer.quotes.latest_versions
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
      redirect_to @quote
    else
      ensure_quote_item_row
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @document_kind = resolved_document_kind
  end

  def edit
    ensure_quote_item_row
  end

  def update
    @quote.template ||= current_user.company.quote_template_or_default

    if @quote.update(quote_params)
      redirect_to @quote
    else
      ensure_quote_item_row
      render :edit, status: :unprocessable_entity
    end
  end

  def update_template
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
        render turbo_stream: turbo_stream.replace(
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
    @quote.destroy
    redirect_to @quote.customer
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

    if pdf_client && wkhtmltopdf_available?
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
    revision = @quote.build_revision
    revision.status = "draft" if revision.status.blank? || revision.status == "expired"
    revision.save!
    redirect_to edit_quote_path(revision), notice: "Revision V#{revision.revision_number} created. Update pricing and share."
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Quote duplicate_and_reprice failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: "Unable to create revision: #{e.record.errors.full_messages.to_sentence}"
  rescue ActiveModel::UnknownAttributeError => e
    Rails.logger.error("Quote duplicate_and_reprice failed: #{e.class} #{e.message}")
    redirect_to quote_path(@quote), alert: "Revision failed due to schema mismatch. Please run database migrations on the server."
  end

  def share
    token = QuoteShare.generate_token
    snapshot = @quote.as_json
    snapshot["customer_name"] = @quote.customer.name
    snapshot["customer_contact_name"] = @quote.customer.contact_name
    snapshot["customer_address"] = @quote.customer.address
    snapshot["customer_phone"] = @quote.customer.phone
    snapshot["customer_email"] = @quote.customer.email
    snapshot["trade_term"] = @quote.trade_term
    snapshot["quote_items"] = @quote.quote_items.map { |item| build_quote_item_snapshot(item) }

    current_user.company.quote_shares.create!(quote: @quote, token: token, snapshot: snapshot)
    quote_status = @quote.status.to_s
    next_status = Quote::AUTO_VIEW_STATUSES.include?(quote_status) || quote_status.blank? ? "sent" : quote_status
    @quote.update_columns(sent_at: @quote.sent_at || Time.current, status: next_status)

    share_url = public_quote_share_url(token, doc: resolved_document_kind)

    respond_to do |format|
      format.json { render json: { url: share_url, token: token } }
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

  private

  def set_customer
    @customer = current_user.company.customers.find(params[:customer_id])
  end

  def set_quote
    Quote.expire_overdue_for_company!(current_user.company_id)
    @quote = current_user.company.quotes.includes({ quote_items: :product }, :customer, :template, :quote_shares).find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :quote_no,
      :currency,
      :issued_on,
      :valid_until,
      :payment_term,
      :trade_term,
      :status,
      :negotiated,
      :final_amount,
      :loss_reason,
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

  def build_quote_item_snapshot(item)
    snapshot = item.as_json
    snapshot["product_name"] = item.product&.name
    snapshot["specifications"] = item.specification_pairs
    snapshot["addon_charges"] = item.addon_charge_entries
    product_image = item.product&.display_image
    snapshot["product_image_path"] = if product_image.present?
      Rails.application.routes.url_helpers.rails_blob_path(product_image, only_path: true)
    end
    snapshot
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

  def wkhtmltopdf_available?
    exe_path = configured_wkhtmltopdf_path.to_s
    return false if exe_path.blank?

    File.exist?(exe_path)
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
end
