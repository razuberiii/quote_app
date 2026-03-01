class EmailChangesController < ApplicationController
  before_action :authenticate_user!, except: [ :confirm ]
  skip_before_action :ensure_email_verified!, only: [ :confirm ]

  def request_change
    @user = current_user

    # Validate password
    unless @user.valid_password?(params[:current_password])
      return render json: { error: "Invalid password" }, status: :unauthorized
    end

    new_email = params[:new_email]&.strip&.downcase

    # Basic validation
    unless new_email.present? && new_email =~ URI::MailTo::EMAIL_REGEXP
      return render json: { error: "Invalid email format" }, status: :unprocessable_entity
    end

    # Check if email is already in use
    if @user.email == new_email
      return render json: { error: "This is your current email" }, status: :unprocessable_entity
    end

    if User.where(email: new_email).where.not(id: @user.id).exists?
      return render json: { error: "Email already in use" }, status: :unprocessable_entity
    end

    # Generate and send confirmation email
    if EmailChangeService.generate_and_send(@user, new_email)
      render json: {
        success: true,
        message: "Verification email sent to #{new_email}. Please check your email to confirm the change."
      }
    else
      render json: { error: "Failed to send verification email" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[email_changes#request_change] #{e.class}: #{e.message}")
    render json: { error: "An error occurred. Please try again." }, status: :unprocessable_entity
  end

  def confirm
    token = params[:token]

    if EmailChangeService.verify_token(token)
      render :confirmed
    else
      render :invalid, status: :unprocessable_entity
    end
  end
end
