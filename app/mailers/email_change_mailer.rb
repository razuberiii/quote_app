class EmailChangeMailer < ApplicationMailer
  def confirmation_email
    @user = params[:user]
    @new_email = params[:new_email]
    @token = params[:token]

    # Build confirmation URL using Rails configuration
    @confirmation_url = Rails.application.routes.url_helpers.email_change_url(
      token: @token,
      host: ENV.fetch("RAILS_HOST", Rails.application.config.action_mailer.default_url_options[:host]),
      protocol: ENV.fetch("RAILS_PROTOCOL", "https")
    )

    mail(
      to: @new_email,
      subject: "Confirm Your New Email Address - Rubusoo"
    )
  end
end
