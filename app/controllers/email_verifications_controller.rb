class EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :pending ]
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
end
