class QuoteExportsController < ApplicationController
  def show
    quote = current_user.company.quotes.find(params[:quote_id])
    version = quote.quote_revisions.where.not(published_at: nil).find(params[:version_id])
    output = params[:output].presence_in(%w[pdf excel customer_excel])
    raise ActiveRecord::RecordNotFound unless output

    generated = if output == "customer_excel"
      template_id = version.snapshot.dig("workbook_template", "id")
      template = current_user.company.workbook_templates.find(template_id)
      CustomerWorkbookGenerator.new(version, template).generate
    else
      PublishedVersionFileGenerator.new(version).public_send(output)
    end
    send_data generated.io.read, filename: generated.filename, type: generated.content_type, disposition: "attachment"
  end
end
