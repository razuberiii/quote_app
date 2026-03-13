class FollowUpMailer < ApplicationMailer
  def follow_up_email
    @customer = params[:customer]
    @message = params[:message].to_s
    @sender = params[:sender]
    @quote = params[:quote]
    @company = @customer.company

    I18n.with_locale(resolved_follow_up_locale) do
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

  private

  def resolved_follow_up_locale
    template = @quote&.template || @customer&.company&.quote_template_or_default
    template&.output_locale_for(:webview).presence || I18n.default_locale
  end
end
