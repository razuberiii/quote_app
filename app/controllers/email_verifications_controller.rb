class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :pending, :resend, :verify ]
  skip_before_action :ensure_email_verified!, only: [ :pending, :resend, :verify ]
  layout "application"

  def pending
    @pending_email = current_user&.email.presence || params[:email].to_s.strip.downcase.presence
    @auto_send_state = params[:auto_send].to_s
    @auto_send_cooldown = params[:cooldown].to_i
    @initial_cooldown = params[:initial_cooldown].to_i
    @resend_cooldown_seconds = EmailVerificationService::RESEND_COOLDOWN_SECONDS
    @code_length = EmailVerificationService::CODE_LENGTH
    @code_validity_minutes = EmailVerificationService::CODE_VALIDITY_SECONDS / 60
    @max_attempts = EmailVerificationService::MAX_ATTEMPTS
  end

  def verify
    user = verification_target_user
    return render_invalid_code unless user.present?

    result = EmailVerificationService.new(user).verify_code(params[:code].to_s)

    case result
    when :verified
      render json: { success: true, message: t("email_verifications.flash.verified_success") }
    when :already_verified
      render json: { success: true, message: t("email_verifications.flash.already_verified") }
    when :expired
      render json: { error: t("email_verifications.flash.code_expired") }, status: :unprocessable_entity
    when :too_many_attempts
      render json: { error: t("email_verifications.flash.too_many_attempts") }, status: :too_many_requests
    else
      render_invalid_code
    end
  rescue StandardError => e
    Rails.logger.error("[email_verifications#verify] #{e.class}: #{e.message}")
    render json: { error: t("email_verifications.flash.error_occurred") }, status: :unprocessable_entity
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
        message: current_user.present? ? t("email_verifications.flash.sent_to", email: user.email) : t("email_verifications.flash.generic_sent"),
        cooldown: EmailVerificationService::RESEND_COOLDOWN_SECONDS
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

  def verification_target_user
    return current_user if current_user.present?

    email = params[:email].to_s.strip.downcase
    return nil if email.blank?

    User.find_by("LOWER(email) = ?", email)
  end

  def render_invalid_code
    render json: { error: t("email_verifications.flash.invalid_code") }, status: :unprocessable_entity
  end
end
