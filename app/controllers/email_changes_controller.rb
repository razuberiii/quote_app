class EmailChangesController < ApplicationController
  before_action :authenticate_user!, except: [ :confirm ]
  skip_before_action :ensure_email_verified!, only: [ :confirm ]

  def request_change
    @user = current_user

    unless verify_turnstile!
      return
    end

    # Validate password
    unless @user.valid_password?(params[:current_password])
      return render json: { error: t("email_changes.flash.invalid_password") }, status: :unauthorized
    end

    new_email = params[:new_email]&.strip&.downcase

    # Basic validation
    unless new_email.present? && new_email =~ URI::MailTo::EMAIL_REGEXP
      return render json: { error: t("email_changes.flash.invalid_email_format") }, status: :unprocessable_entity
    end

    # Check if email is already in use
    if @user.email == new_email
      return render json: { error: t("email_changes.flash.current_email") }, status: :unprocessable_entity
    end

    if User.where(email: new_email).where.not(id: @user.id).exists?
      return render json: { error: t("email_changes.flash.email_in_use") }, status: :unprocessable_entity
    end

    # Generate and send confirmation email
    if EmailChangeService.generate_and_send(
      @user,
      new_email,
      host: trusted_public_url_options[:host],
      protocol: trusted_public_url_options[:protocol].to_sym
    )
      render json: {
        success: true,
        message: t("email_changes.flash.verification_sent", email: new_email)
      }
    else
      render json: { error: t("email_changes.flash.failed_send") }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[email_changes#request_change] #{e.class}: #{e.message}")
    render json: { error: t("email_changes.flash.error_occurred") }, status: :unprocessable_entity
  end

  def confirm
    token = params[:token]

    if EmailChangeService.verify_token(token)
      render :confirmed
    else
      render :invalid, status: :unprocessable_entity
    end
  end

  private

  def verify_turnstile!
    verify_turnstile_for_json!(
      token: params[:cf_turnstile_response],
      missing_message: t("email_changes.flash.bot_verification_required"),
      failed_message: t("email_changes.flash.bot_verification_failed")
    )
  end
end
