class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :pending, :resend ]
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
    @pending_email = current_user&.email.presence || params[:email].to_s.strip.downcase.presence
  end

  def resend
    unless verify_turnstile!
      return
    end

    user = resend_target_user

    unless user.present?
      return render json: {
        success: true,
        message: "If an account with that email exists, a verification email has been sent."
      }
    end

    if user.email_verified?
      return render json: {
        success: true,
        message: "This email is already verified. Please log in."
      }
    end

    # Check if user can resend (cooldown check)
    unless EmailVerificationService.can_resend?(user)
      seconds_left = EmailVerificationService.seconds_until_resend_allowed(user)
      return render json: {
        error: "Please wait #{seconds_left} seconds before requesting again",
        seconds_left: seconds_left
      }, status: :too_many_requests
    end

    # Generate and send verification email
    service = EmailVerificationService.new(user)
    if service.send_verification_email(request.host_with_port, request.scheme.to_sym)
      render json: {
        success: true,
        message: current_user.present? ? "Verification email sent to #{user.email}" : "If an account with that email exists, a verification email has been sent."
      }
    else
      render json: { error: "Failed to send verification email" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[email_verifications#resend] #{e.class}: #{e.message}")
    render json: { error: "An error occurred" }, status: :unprocessable_entity
  end

  private

  def verify_turnstile!
    verify_turnstile_for_json!(
      token: params[:cf_turnstile_response],
      missing_message: "Bot verification is required",
      failed_message: "Bot verification failed. Please try again."
    )
  end

  def resend_target_user
    return current_user if current_user.present?

    email = params[:email].to_s.strip.downcase
    return nil if email.blank?

    User.find_by("LOWER(email) = ?", email)
  end
end
