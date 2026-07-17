require "test_helper"

class PurchaseOrderAttachmentParserTest < ActiveSupport::TestCase
  setup do
    @quote = quotes(:one)
    @quote.update!(status: "draft", valid_until: 30.days.from_now, trade_term: "CIF Hamburg",
      payment_term: "30% deposit", shipping_amount: 350, shipping_price_source: "manual")
    @quote.quote_items.each_with_index { |item, index| item.update!(sku_snapshot: "PO-SKU-#{index + 1}", unit_snapshot: "set") }
    @version = RevisionPublisher.new(quote: @quote, actor: users(:one)).call.revision
  end

  test "CSV purchase order matches reordered rows by SKU and reports material quantity changes" do
    rows = @version.snapshot["quote_items"].reverse
    csv = CSV.generate do |data|
      data << %w[SKU Description Quantity Unit Unit_price Amount]
      rows.each_with_index do |item, index|
        quantity = index.zero? ? item["quantity"].to_d + 2 : item["quantity"]
        data << [ item["sku_snapshot"], item["description"], quantity, item["unit_snapshot"], item["unit_price"], quantity.to_d * item["unit_price"].to_d ]
      end
    end
    response = response_with(csv, "buyer-po.csv", "text/csv")
    review = PurchaseOrderComparator.new(response).call

    assert_equal "csv", review["parser"]
    assert_equal "material_difference", review["severity"]
    assert review["changes"].any? { |change| change["path"].end_with?("quantity") && change["match_confidence"] == "sku" }
    assert_not review["changes"].any? { |change| %w[added removed].include?(change["kind"]) }
  end

  test "PDF purchase order extracts commercial fields without treating the attachment as trusted data" do
    require "prawn"
    pdf = Prawn::Document.new
    pdf.text "Purchase Order: PO-8807"
    pdf.text "Currency: USD"
    pdf.text "Incoterm: CIF Hamburg"
    pdf.text "Payment terms: 30% deposit"
    pdf.text "Grand total: USD 1.00"
    response = response_with(pdf.render, "buyer-po.pdf", "application/pdf")
    review = PurchaseOrderComparator.new(response).call

    assert_equal "pdf_text", review["parser"]
    assert_equal "PO-8807", review["po_number"]
    assert_equal "material_difference", review["severity"]
  end

  test "unreadable PO remains reviewable evidence" do
    response = response_with("not a zip", "buyer-po.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    review = PurchaseOrderComparator.new(response).call
    assert_equal "unreadable", review["parser"]
    assert review["parser_error"].present?
    assert_equal "review_required", review["severity"]
  end

  private

  def response_with(content, filename, content_type)
    response = @quote.deal_responses.new(company: @quote.company, quote_revision: @version, recorded_by: users(:one),
      kind: "purchase_order", source: "purchase_order", body: "", received_at: Time.current, idempotency_key: SecureRandom.uuid)
    response.attachment.attach(io: StringIO.new(content), filename:, content_type:)
    response.save!
    response
  end
end
