class ContactRequestsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public_marketing"

  def create
    turnstile_token = params.dig(:contact_request, :cf_turnstile_response)
    unless verify_turnstile_for_html!(
      token: turnstile_token,
      on_missing: -> {
        flash.now[:alert] = t("contact_requests.flash.bot_verification_required")
        render_contact_error(:unprocessable_entity)
      },
      on_failed: -> {
        flash.now[:alert] = t("contact_requests.flash.bot_verification_failed")
        render_contact_error(:unprocessable_entity)
      }
    )
      return
    end

    @contact_request = ContactRequest.new(contact_request_params)

    if @contact_request.valid?
      ContactMailer.with(contact_request: @contact_request).inquiry_email.deliver_now
      redirect_to(source_page_path, notice: t("contact_requests.flash.received"))
    else
      flash.now[:alert] = @contact_request.errors.full_messages.to_sentence
      render_contact_error(:unprocessable_entity)
    end
  rescue StandardError => e
    Rails.logger.error("[contact_requests#create] #{e.class}: #{e.message}")
    flash.now[:alert] = t("contact_requests.flash.send_failed")
    render_contact_error(:unprocessable_entity)
  end

  private

  def source_page_path
    params[:source_page] == "contact" ? contact_path : root_path
  end

  def render_contact_error(status)
    @contact_request ||= ContactRequest.new
    @contact_email = ContactMailer.contact_email_for_environment
    @demo_path = demo_path
    @sample_quote_path = sample_quote_path
    @resources_path = resources_path
    template = params[:source_page] == "contact" ? "landing/contact" : "landing/index"
    render template, status: status
  end

  def contact_request_params
    params.require(:contact_request).permit(:name, :email, :company, :team_size, :inquiry_type, :message, :website)
  end
end
