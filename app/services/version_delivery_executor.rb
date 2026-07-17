class VersionDeliveryExecutor
  class UnsupportedChannel < StandardError; end

  def initialize(delivery)
    @delivery = delivery
  end

  def call
    raise UnsupportedChannel, "External delivery must be recorded manually" unless @delivery.system_executed?
    @delivery.update!(status: "queued", error_message: nil)
    case @delivery.channel
    when "buyer_room_link"
      @delivery.update!(status: "sent", delivered_at: Time.current)
    when "email_link", "email_pdf", "email_link_pdf"
      attach_file(:pdf) if %w[email_pdf email_link_pdf].include?(@delivery.channel)
      VersionDeliveryMailer.with(delivery: @delivery).deliver_version.deliver_now
      @delivery.update!(status: "sent", delivered_at: Time.current)
    when "pdf_download"
      attach_file(:pdf)
      @delivery.update!(status: "generated", generated_at: Time.current)
    when "excel_export"
      attach_file(:excel)
      @delivery.update!(status: "generated", generated_at: Time.current)
    end
    @delivery
  rescue StandardError => error
    @delivery.update_columns(status: "failed", error_message: error.message.to_s.first(1_000), updated_at: Time.current)
    raise
  end

  private

  def attach_file(kind)
    generated = PublishedVersionFileGenerator.new(@delivery.quote_revision).public_send(kind)
    @delivery.generated_file.attach(io: generated.io, filename: generated.filename, content_type: generated.content_type)
    @delivery.update!(file_name: generated.filename, file_size: generated.byte_size, generated_at: Time.current)
  end
end
