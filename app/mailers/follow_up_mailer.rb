class FollowUpMailer < ApplicationMailer
  def follow_up_email
    @customer = params[:customer]
    @message = params[:message].to_s
    @sender = params[:sender]
    @quote = params[:quote]
    @company = @customer.company

    mail(
      to: @customer.email,
      subject: I18n.t(
        "follow_up.mailer.subject",
        company_name: @company.name,
        customer_name: @customer.contact_name.presence || @customer.name
      )
    )
  end
end
