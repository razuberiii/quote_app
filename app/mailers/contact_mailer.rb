class ContactMailer < ApplicationMailer
  def self.contact_email_for_environment
    if Rails.env.production?
      ENV.fetch("LANDING_CONTACT_EMAIL", "hello@quoteapp.local")
    else
      ENV["LANDING_CONTACT_EMAIL_DEV"].presence || ENV.fetch("LANDING_CONTACT_EMAIL", "hello@quoteapp.local")
    end
  end

  def inquiry_email
    @contact_request = params.fetch(:contact_request)
    @inquiry_label = inquiry_label(@contact_request.normalized_inquiry_type)

    mail(
      to: self.class.contact_email_for_environment,
      subject: "[Rubusoo] #{@inquiry_label} inquiry from #{@contact_request.name}",
      reply_to: @contact_request.email
    )
  end

  private

  def inquiry_label(type)
    case type
    when "vip" then "VIP"
    when "support" then "Support"
    else "General"
    end
  end
end
