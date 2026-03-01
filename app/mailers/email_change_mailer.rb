class EmailChangeMailer < ApplicationMailer
  def confirmation_email
    @user = params[:user]
    @new_email = params[:new_email]
    @token = params[:token]
    host = params[:host].presence || ENV["APP_HOST"].presence || ENV["RAILS_HOST"].presence || Rails.application.config.action_mailer.default_url_options[:host]
    protocol = params[:protocol].presence || ENV.fetch("RAILS_PROTOCOL", "https")

    @confirmation_url = Rails.application.routes.url_helpers.email_change_url(
      token: @token,
      host: host,
      protocol: protocol
    )

    mail(
      to: @new_email,
      subject: "Confirm Your New Email Address - Rubusoo"
    )
  end
end
