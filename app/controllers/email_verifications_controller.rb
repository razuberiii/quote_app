class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :pending ]
  skip_before_action :ensure_email_verified!, only: [ :show, :pending, :resend ]
  layout "application"

  def show
    @token = params[:token]

    if EmailVerificationService.verify_token(@token)
      redirect_to new_user_session_path, notice: "Email verified successfully! You can now log in."
    else
      render :invalid, status: :unprocessable_entity
    end
  end

  def pending
    # Show page for users who need to verify their email before logging in
  end

  def resend
    # Only authenticated users can request resend
    unless current_user.present?
      return render json: { error: "Please log in" }, status: :unauthorized
    end

    # Verify Turnstile if not disabled
    unless ENV["SKIP_TURNSTILE_VERIFICATION"] == "true"
      turnstile_token = params[:cf_turnstile_response]

      unless turnstile_token.present?
        return render json: { error: "Bot verification is required" }, status: :unprocessable_entity
      end

      service = TurnstileVerificationService.new(turnstile_token, request.remote_ip)

      unless service.verify
        return render json: { error: "Bot verification failed. Please try again." }, status: :unprocessable_entity
      end
    end

    # Check if user can resend (cooldown check)
    if !EmailVerificationService.can_resend?(current_user)
      seconds_left = EmailVerificationService.seconds_until_resend_allowed(current_user)
      return render json: {
        error: "Please wait #{seconds_left} seconds before requesting again",
        seconds_left: seconds_left
      }, status: :too_many_requests
    end

    # Generate and send verification email
    service = EmailVerificationService.new(current_user)
    if service.send_verification_email(request.host_with_port, request.scheme.to_sym)
      render json: {
        success: true,
        message: "Verification email sent to #{current_user.email}"
      }
    else
      render json: { error: "Failed to send verification email" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[email_verifications#resend] #{e.class}: #{e.message}")
    render json: { error: "An error occurred" }, status: :unprocessable_entity
  end
end
