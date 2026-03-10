class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :pending, :resend ]
  skip_before_action :ensure_email_verified!, only: [ :show, :pending, :resend ]
  layout "application"

  def show
    @token = params[:token]

    if EmailVerificationService.verify_token(@token)
      redirect_to new_user_session_path, notice: t("email_verifications.flash.verified_success")
    else
      render :invalid, status: :unprocessable_entity
    end
  end

  def pending
    # Show page for users who need to verify their email before logging in
    @pending_email = current_user&.email.presence || params[:email].to_s.strip.downcase.presence
    @auto_send_state = params[:auto_send].to_s
    @auto_send_cooldown = params[:cooldown].to_i
  end

  def resend
    unless verify_turnstile!
      return
    end

    user = resend_target_user

    unless user.present?
      return render json: {
        success: true,
        message: t("email_verifications.flash.generic_sent")
      }
    end

    if user.email_verified?
      return render json: {
        success: true,
        message: t("email_verifications.flash.already_verified")
      }
    end

    # Check if user can resend (cooldown check)
    unless EmailVerificationService.can_resend?(user)
      seconds_left = EmailVerificationService.seconds_until_resend_allowed(user)
      return render json: {
        error: t("email_verifications.flash.wait_before_request", seconds: seconds_left),
        seconds_left: seconds_left
      }, status: :too_many_requests
    end

    # Generate and send verification email
    service = EmailVerificationService.new(user)
    if service.send_verification_email(request.host_with_port, request.scheme.to_sym)
      render json: {
        success: true,
        message: current_user.present? ? t("email_verifications.flash.sent_to", email: user.email) : t("email_verifications.flash.generic_sent")
      }
    else
      render json: { error: t("email_verifications.flash.failed_send") }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[email_verifications#resend] #{e.class}: #{e.message}")
    render json: { error: t("email_verifications.flash.error_occurred") }, status: :unprocessable_entity
  end

  private

  def verify_turnstile!
    verify_turnstile_for_json!(
      token: params[:cf_turnstile_response],
      missing_message: t("email_verifications.flash.bot_verification_required"),
      failed_message: t("email_verifications.flash.bot_verification_failed")
    )
  end

  def resend_target_user
    return current_user if current_user.present?

    email = params[:email].to_s.strip.downcase
    return nil if email.blank?

    User.find_by("LOWER(email) = ?", email)
  end
end
