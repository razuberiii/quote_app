class ContactRequestsController < ApplicationController
  skip_before_action :authenticate_user!

  def create
    turnstile_token = params.dig(:contact_request, :cf_turnstile_response)
    unless verify_turnstile_for_html!(
      token: turnstile_token,
      on_missing: -> {
        flash.now[:alert] = "Bot verification is required. Please complete the CAPTCHA."
        render "landing/index", status: :unprocessable_entity
      },
      on_failed: -> {
        flash.now[:alert] = "Bot verification failed. Please try again."
        render "landing/index", status: :unprocessable_entity
      }
    )
      return
    end

    @contact_request = ContactRequest.new(contact_request_params)

    if @contact_request.valid?
      ContactMailer.with(contact_request: @contact_request).inquiry_email.deliver_now
      redirect_to root_path, notice: "Thanks! We received your message and will reply by email."
    else
      flash.now[:alert] = @contact_request.errors.full_messages.to_sentence
      render "landing/index", status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[contact_requests#create] #{e.class}: #{e.message}")
    flash.now[:alert] = "Message send failed. Please try again in a moment, or email us directly."
    render "landing/index", status: :unprocessable_entity
  end

  private

  def contact_request_params
    params.require(:contact_request).permit(:name, :email, :company, :team_size, :inquiry_type, :message, :website)
  end
end
