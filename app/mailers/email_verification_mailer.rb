class EmailVerificationMailer < ApplicationMailer
  def verification_email
    @user = params.fetch(:user)
    @verification_link = params.fetch(:verification_link)

    mail(
      to: @user.email,
      subject: "Verify your email address"
    )
  end
end
