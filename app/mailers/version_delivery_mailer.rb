class VersionDeliveryMailer < ApplicationMailer
  def deliver_version
    @delivery = params[:delivery]
    @revision = @delivery.quote_revision
    @buyer_room_url = buyer_room_url(@revision.secure_token)
    if @delivery.generated_file.attached?
      attachments[@delivery.generated_file.filename.to_s] = @delivery.generated_file.download
    end
    headers["X-Rubusoo-Version"] = @revision.id.to_s
    mail(to: @delivery.recipient, cc: @delivery.cc.presence, subject: @delivery.subject)
  end
end
