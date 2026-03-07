class QuoteMailer < ApplicationMailer
  def share_email
    @quote = params[:quote]
    @share = params[:share]
    @reminder = ActiveModel::Type::Boolean.new.cast(params[:reminder])
    @customer = @quote.customer
    @company = @quote.company
    @document_kind = params[:document_kind].presence
    @url_options = params[:url_options] || {}
    @public_url = Rails.application.routes.url_helpers.public_quote_share_url(@share.token, { doc: @document_kind }.merge(@url_options))
    @email_subject = resolved_subject
    @email_body = resolved_body
    @email_cta_label = resolved_cta_label

    mail(
      to: @customer.email,
      subject: @email_subject
    )
  end

  private

  def resolved_subject
    return @company.reminder_email_subject_for(quote: @quote, customer: @customer) if @reminder

    "Quotation: #{@quote.quote_no} from #{@company.name}"
  end

  def resolved_body
    return @company.reminder_email_body_for(quote: @quote, customer: @customer) if @reminder

    "Your quotation #{@quote.quote_no} from #{@company.name} is ready."
  end

  def resolved_cta_label
    return @company.reminder_email_cta_label_resolved if @reminder

    "Open quotation"
  end
end
