class QuoteExportsController < ApplicationController
  def show
    quote = current_user.company.quotes.find(params[:quote_id])
    version = quote.quote_revisions.where.not(published_at: nil).find(params[:version_id])
    output = params[:output].presence_in(%w[pdf excel])
    raise ActiveRecord::RecordNotFound unless output

    generated = PublishedVersionFileGenerator.new(version).public_send(output)
    send_data generated.io.read, filename: generated.filename, type: generated.content_type, disposition: "attachment"
  end
end
