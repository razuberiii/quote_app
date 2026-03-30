require "test_helper"

class PublicQuoteSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @quote = quotes(:one)
    @quote.customer.update_columns(internal_owner_id: users(:one).id) if Customer.internal_owner_enabled?
    @quote.customer.update_columns(phone_country_code: "+86", phone: "138 0013 8000")
    @quote.update!(status: "sent", sent_at: 3.days.ago, viewed_at: nil)
    @share = QuoteShare.create!(company: @quote.company, quote: @quote, token: QuoteShare.generate_token, snapshot: QuoteSnapshotBuilder.new(@quote).as_json)
  end

  test "snapshot keeps formatted customer phone" do
    assert_equal "+86 138 0013 8000", @share.snapshot["customer_phone"]
  end

  test "snapshot includes configuration, detail pictures, and container loading blocks" do
    detail_blob = create_test_image_blob(filename: "detail-picture-snapshot.png")
    @quote.update!(
      configuration_block: {
        "rows" => [ { "label" => "Motor", "value" => "72V 7.5kW", "source" => "quote", "position" => 1 } ]
      },
      detail_pictures_block: {
        "enabled" => true,
        "items" => [ { "image_blob_id" => detail_blob.id.to_s, "caption" => "Controller panel", "source" => "quote_upload", "position" => 1 } ]
      },
      container_loading_block: {
        "enabled" => true,
        "rows" => [ { "variant" => "14 seats", "container_type" => "40HQ", "capacity" => "2 units", "note" => "", "position" => 1 } ]
      }
    )
    @share.update!(snapshot: QuoteSnapshotBuilder.new(@quote).as_json)

    assert_equal "Motor", @share.snapshot.dig("configuration_block", "rows", 0, "label")
    assert_equal true, @share.snapshot.dig("detail_pictures_block", "enabled")
    assert_equal detail_blob.id.to_s, @share.snapshot.dig("detail_pictures_block", "items", 0, "image_blob_id")
    assert_equal true, @share.snapshot.dig("container_loading_block", "enabled")
    assert_equal "14 seats", @share.snapshot.dig("container_loading_block", "rows", 0, "variant")
  end

  test "request revision persists reason and message" do
    assert_difference("Notification.count", 1) do
      post request_revision_public_quote_share_url(@share.token), params: {
        request_reason: "specification change",
        client_message: "Need a lower voltage option"
      }
    end

    assert_response :redirect
    assert_match(%r{/public/quote_shares/#{@share.token}}, response.headers["Location"])
    @quote.reload
    assert_equal "specification change", @quote.request_reason
    assert_equal "Need a lower voltage option", @quote.changes_request_message
    assert_equal "negotiating", @quote.status
    assert_equal "quote_revision_requested", Notification.order(:created_at).last.normalized_kind
  end

  test "accept creates notification for internal owner" do
    assert_difference("Notification.count", 1) do
      post accept_public_quote_share_url(@share.token)
    end

    assert_response :redirect
    @quote.reload
    assert_equal "won", @quote.status
    assert_equal "quote_accepted", Notification.order(:created_at).last.normalized_kind
  end

  test "show falls back to data-driven advanced visibility for legacy snapshots" do
    legacy_snapshot = @share.snapshot.deep_dup
    legacy_snapshot["advanced_mode"] = true
    legacy_snapshot["advanced_trade_terms"] = { "hs_code" => "8703.10" }
    legacy_snapshot["advanced_logistics"] = {}
    legacy_snapshot.delete("advanced_visibility")
    @share.update!(snapshot: legacy_snapshot)

    get public_quote_share_url(@share.token)
    assert_response :success
    assert_includes response.body, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_includes response.body, "8703.10"
  end

  test "show remains stable when legacy snapshot misses advanced keys entirely" do
    legacy_snapshot = @share.snapshot.deep_dup
    legacy_snapshot.delete("advanced_mode")
    legacy_snapshot.delete("advanced_trade_terms")
    legacy_snapshot.delete("advanced_logistics")
    legacy_snapshot.delete("advanced_visibility")
    @share.update!(snapshot: legacy_snapshot)

    get public_quote_share_url(@share.token)
    assert_response :success
    assert_not_includes response.body, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_not_includes response.body, I18n.t("quotes.view.show.shipping_and_logistics", default: "Shipping & Logistics")
  end

  test "pi public share hides accept and revision actions" do
    pi_quote = Quote.create!(
      company: @quote.company,
      customer: @quote.customer,
      template: @quote.company.quote_templates.where(document_kind: "proforma_invoice").first || @quote.template,
      source_quote: @quote,
      currency: @quote.currency,
      issued_on: Date.current,
      status: "draft",
      quote_items_attributes: [ { description: "PI row", unit_price: 10, quantity: 1 } ]
    )
    pi_share = QuoteShare.create!(
      company: pi_quote.company,
      quote: pi_quote,
      token: QuoteShare.generate_token,
      snapshot: QuoteSnapshotBuilder.new(pi_quote).as_json
    )

    get public_quote_share_url(pi_share.token, doc: "pi")
    assert_response :success
    assert_includes response.body, I18n.t("public_quote_shares.pi_document_notice")
    assert_not_includes response.body, "Accept Quotation"
    assert_not_includes response.body, "Request Revision"
  end

  test "public share keeps fixed module order when extension blocks are present" do
    detail_blob = create_test_image_blob(filename: "detail-picture-order.png")
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: {
        "hs_code" => "8703.10",
        "payment_clause_note" => "T/T 30% + 70%",
        "warranty_scope_note" => Array.new(5, "Warranty covers vehicle body and electric system for 12 months, including remote support and replacement part policy across ports.").join(" ")
      },
      advanced_logistics: {
        "container_type" => "40HQ",
        "freight_note" => "Port-to-port",
        "container_loading_note" => "2 units / 40HQ"
      },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      },
      configuration_block: {
        "enabled" => true,
        "rows" => [ { "label" => "Motor", "value" => "72V 7.5kW", "source" => "quote", "position" => 1 } ]
      },
      detail_pictures_block: {
        "enabled" => true,
        "items" => [ { "image_blob_id" => detail_blob.id.to_s, "caption" => "Controller panel", "source" => "quote_upload", "position" => 1 } ]
      },
      container_loading_block: {
        "enabled" => true,
        "rows" => [ { "variant" => "14 seats", "container_type" => "40HQ", "capacity" => "2 units", "note" => "", "position" => 1 } ]
      },
      terms_text: "After-sales coverage applies."
    )
    @share.update!(snapshot: QuoteSnapshotBuilder.new(@quote).as_json)

    get public_quote_share_url(@share.token)
    assert_response :success

    summary_index = response.body.index(I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms"))
    config_index = response.body.index(I18n.t("quote_document.sections.configuration", default: "Configuration"))
    picture_index = response.body.index(I18n.t("quote_document.sections.detail_pictures", default: "Detail Pictures"))
    logistics_title = I18n.t("quotes.view.show.shipping_and_logistics", default: "Shipping & Logistics")
    logistics_index = response.body.index(CGI.escapeHTML(logistics_title)) || response.body.index(logistics_title)
    loading_index = response.body.index(I18n.t("quotes.view.show.field_labels.container_loading", default: "Container Loading"))
    narrative_index =
      response.body.index(I18n.t("quote_document.sections.commercial_notes", default: "Commercial Notes")) ||
      response.body.index(I18n.t("quote_document.sections.logistics_notes", default: "Logistics Notes")) ||
      response.body.index(I18n.t("quote_document.sections.terms_and_conditions")) ||
      response.body.index(I18n.t("quote_document.labels.notes"))

    assert summary_index
    assert config_index
    assert picture_index
    assert logistics_index
    assert loading_index
    assert narrative_index
    assert_operator summary_index, :<, config_index
    assert_operator config_index, :<, picture_index
    assert_operator picture_index, :<, logistics_index
    assert_operator logistics_index, :<, loading_index
    assert_operator loading_index, :<, narrative_index
    assert_includes response.body, "quote-detail-pictures-grid"
    assert_includes response.body, "quote-mini-table--container-loading"
  end

  private

  def create_test_image_blob(filename: "detail-picture.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image content"),
      filename: filename,
      content_type: "image/png"
    )
  end
end
