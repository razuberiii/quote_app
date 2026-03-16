class EmailVerificationMailer < ApplicationMailer
  def verification_email
    @user = params.fetch(:user)
    @verification_code = params.fetch(:verification_code)
    @validity_minutes = params.fetch(:validity_minutes, 15)

    mail(
      to: @user.email,
      subject: I18n.t("email_verifications.mailer.subject")
    )
  end
end
