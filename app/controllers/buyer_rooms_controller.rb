class BuyerRoomsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "buyer_room"
  before_action :load_revision
  before_action :ensure_actionable!, except: %i[show pdf]

  def show
    @snapshot = @revision.snapshot
    @state = buyer_room_state
    track_view unless params[:preview] == "1"
  end

  def pdf
    @snapshot = @revision.snapshot
    html = render_to_string(template: "buyer_rooms/pdf", layout: "pdf", formats: [:html])
    pdf = ChromiumPdfRenderer.new(html).render
    send_data pdf, filename: "#{@revision.quote.quote_no}-R#{@revision.number}.pdf",
      type: "application/pdf", disposition: "attachment"
  rescue StandardError => error
    Rails.logger.error("Buyer PDF failed: #{error.class}: #{error.message}")
    redirect_to buyer_room_path(@revision.secure_token), alert: "PDF generation is temporarily unavailable."
  end

  def question
    question = @revision.buyer_questions.create!(
      company: @revision.company,
      context_type: params[:context_type].presence || "quote",
      context_key: params[:context_key], buyer_name: params[:buyer_name], buyer_email: params[:buyer_email],
      body: params.require(:body), idempotency_key: idempotency_key
    )
    track("question", question.id)
    Notification.create_quote_revision_requested_notification(@revision.quote)
    redirect_to buyer_room_path(@revision.secure_token, event: "question-sent")
  rescue ActiveRecord::RecordNotUnique
    redirect_to buyer_room_path(@revision.secure_token, event: "question-sent")
  end

  def request_changes
    request_record = @revision.change_requests.create!(
      company: @revision.company, buyer_name: params[:buyer_name], buyer_email: params[:buyer_email],
      message: params.require(:message), requested_changes: permitted_selection,
      idempotency_key: idempotency_key
    )
    request_record.attachment.attach(params[:attachment]) if params[:attachment].present?
    @revision.quote.update!(status: "revision_requested", changes_requested_at: Time.current, changes_request_message: request_record.message)
    track("revision_requested", request_record.id)
    Notification.create_quote_revision_requested_notification(@revision.quote)
    redirect_to buyer_room_path(@revision.secure_token, event: "changes-requested")
  rescue ActiveRecord::RecordNotUnique
    redirect_to buyer_room_path(@revision.secure_token, event: "changes-requested")
  end

  def accept
    acceptance = QuoteAcceptor.new(
      revision: @revision, attributes: accept_params.to_h.symbolize_keys,
      selection: permitted_selection, idempotency_key: idempotency_key
    ).call
    track("accepted", acceptance.id)
    Notification.create_quote_accepted_notification(@revision.quote)
    redirect_to buyer_room_path(@revision.secure_token, event: "accepted")
  rescue QuoteAcceptor::NotActionable => error
    redirect_to buyer_room_path(@revision.secure_token, error: error.message)
  end

  private

  def load_revision
    @revision = QuoteRevision.includes(:company, quote: :customer).find_by!(secure_token: params[:token])
  end

  def ensure_actionable!
    raise ActiveRecord::RecordNotFound unless @revision.actionable?
  end

  def buyer_room_state
    return "accepted" if @revision.status == "accepted"
    return "revoked" if @revision.revoked_at?
    return "expired" if @revision.expired?
    return "superseded" if @revision.superseded_at? || @revision.status == "superseded"
    "normal"
  end

  def accept_params
    params.permit(:name, :email, :job_title, :po_number, :note).tap do |values|
      values.require(:name); values.require(:email)
    end
  end

  def permitted_selection
    params.fetch(:selection, ActionController::Parameters.new).permit(
      :plan,
      quantities: {},
      configurations: {},
      accessories: [],
      shipping: {}
    ).to_h
  end

  def idempotency_key
    request.headers["Idempotency-Key"].presence || params[:idempotency_key].presence || request.request_id
  end

  def track(kind, source_id)
    @revision.company.buyer_activities.create!(quote: @revision.quote, quote_revision: @revision, kind: kind,
      metadata: { source_id: source_id }, deduplication_key: "#{kind}:#{source_id}")
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def track_view
    minute = Time.current.utc.strftime("%Y%m%d%H%M")
    track("viewed", "#{Digest::SHA256.hexdigest(request.remote_ip.to_s)[0, 12]}:#{minute}")
  end
end
