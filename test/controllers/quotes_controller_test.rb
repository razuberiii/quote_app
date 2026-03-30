require "test_helper"
require "tempfile"

class QuotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @customer = customers(:one)
    @quote = quotes(:one)
    sign_in @user
  end

  test "new is successful" do
    get new_customer_quote_url(@customer)
    assert_response :success
  end

  test "switching locale persists user language preference" do
    @user.update!(language: "en")

    get new_customer_quote_url(@customer, locale: "zh-CN")
    assert_response :success
    assert_equal "zh-CN", @user.reload.language
  end

  test "new shows extended toggle and fee insert actions" do
    get new_customer_quote_url(@customer)
    assert_response :success
    assert_select "#toggle-quote-advanced-mode", 1
    assert_select "#insert-quote-main-item", 0
    assert_select "#insert-quote-fee-items", 1
    assert_select ".js-open-detail-gallery", 1
    assert_select "input[name='quote[scenario_preset_key]']", 0
  end

  test "new does not prefill scope of supply from demo or template defaults" do
    template = quote_templates(:one)
    template.update!(
      default_template: true,
      show_scope_of_supply: true,
      default_scope_of_supply_content: "Template scoped default content"
    )

    get new_customer_quote_url(@customer)
    assert_response :success
    assert_select "textarea[name='quote[scope_of_supply]']", text: ""
  end

  test "create rejects payload with too many quote item rows" do
    item_attrs = {}
    (Quote::MAX_QUOTE_ITEMS_COUNT + 1).times do |idx|
      item_attrs[idx.to_s] = { description: "Item #{idx}", unit_price: "10", quantity: "1" }
    end

    post customer_quotes_url(@customer), params: {
      quote: {
        currency: "USD",
        quote_items_attributes: item_attrs
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "can include up to #{Quote::MAX_QUOTE_ITEMS_COUNT} items"
  end

  test "update rejects payload with too many image uploads in one request" do
    upload_files = []
    begin
      item_attrs = {}
      (QuotesController::MAX_ITEM_IMAGE_UPLOADS_PER_REQUEST + 1).times do |idx|
        tempfile = Tempfile.new([ "quote-item-image-#{idx}", ".png" ])
        tempfile.binmode
        tempfile.write("png")
        tempfile.rewind
        upload_files << tempfile
        item_attrs[idx.to_s] = {
          description: "Item #{idx}",
          unit_price: "10",
          quantity: "1",
          item_image: Rack::Test::UploadedFile.new(tempfile.path, "image/png")
        }
      end

      patch quote_url(@quote), params: {
        quote: {
          currency: "USD",
          quote_items_attributes: item_attrs
        }
      }

      assert_response :unprocessable_entity
      assert_includes response.body, "Too many images in one request"
    ensure
      upload_files.each do |file|
        file.close
        file.unlink
      rescue StandardError
        nil
      end
    end
  end

  test "update rejects payload with too many detail pictures in one request" do
    detail_items = {}
    (Quote::MAX_DETAIL_PICTURES_ITEMS + 1).times do |idx|
      detail_items[idx.to_s] = {
        image_blob_id: (idx + 1).to_s,
        caption: "Image #{idx}",
        source: "quote_upload",
        position: idx + 1
      }
    end

    patch quote_url(@quote), params: {
      quote: {
        currency: @quote.currency,
        issued_on: @quote.issued_on,
        valid_until: @quote.valid_until,
        payment_term: @quote.payment_term,
        trade_term: @quote.trade_term,
        terms_text: @quote.terms_text,
        delivery_notes: @quote.delivery_notes,
        scope_of_supply: @quote.scope_of_supply,
        detail_pictures_block: {
          enabled: "1",
          items: detail_items
        },
        quote_items_attributes: @quote.quote_items.map.with_index do |item, idx|
          [ idx.to_s, { id: item.id, description: item.description, unit_price: item.unit_price, quantity: item.quantity } ]
        end.to_h
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "items exceed limit (#{Quote::MAX_DETAIL_PICTURES_ITEMS})"
  end

  test "update accepts detail picture batch uploads and stores them in detail pictures block" do
    tempfiles = []
    begin
      uploads = 2.times.map do |idx|
        file = Tempfile.new([ "detail-batch-#{idx}", ".png" ])
        file.binmode
        file.write("png")
        file.rewind
        tempfiles << file
        Rack::Test::UploadedFile.new(file.path, "image/png")
      end

      patch quote_url(@quote), params: {
        quote: {
          currency: @quote.currency,
          issued_on: @quote.issued_on,
          valid_until: @quote.valid_until,
          payment_term: @quote.payment_term,
          trade_term: @quote.trade_term,
          terms_text: @quote.terms_text,
          delivery_notes: @quote.delivery_notes,
          scope_of_supply: @quote.scope_of_supply,
          detail_pictures_batch_uploads: uploads,
          quote_items_attributes: @quote.quote_items.map.with_index do |item, idx|
            [ idx.to_s, { id: item.id, description: item.description, unit_price: item.unit_price, quantity: item.quantity } ]
          end.to_h
        }
      }

      assert_redirected_to quote_url(@quote)
      @quote.reload
      assert_equal true, @quote.detail_pictures_block_data["enabled"]
      assert_operator @quote.detail_pictures_block_data["items"].size, :>=, 2
    ensure
      tempfiles.each do |file|
        file.close
        file.unlink
      rescue StandardError
        nil
      end
    end
  end

  test "update rejects payload with too many container loading rows in one request" do
    loading_rows = {}
    (Quote::MAX_CONTAINER_LOADING_ROWS + 1).times do |idx|
      loading_rows[idx.to_s] = {
        variant: "Variant #{idx}",
        container_type: "40HQ",
        capacity: "2 units",
        note: "",
        position: idx + 1
      }
    end

    patch quote_url(@quote), params: {
      quote: {
        currency: @quote.currency,
        issued_on: @quote.issued_on,
        valid_until: @quote.valid_until,
        payment_term: @quote.payment_term,
        trade_term: @quote.trade_term,
        terms_text: @quote.terms_text,
        delivery_notes: @quote.delivery_notes,
        scope_of_supply: @quote.scope_of_supply,
        container_loading_block: {
          enabled: "1",
          rows: loading_rows
        },
        quote_items_attributes: @quote.quote_items.map.with_index do |item, idx|
          [ idx.to_s, { id: item.id, description: item.description, unit_price: item.unit_price, quantity: item.quantity } ]
        end.to_h
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "rows exceed limit (#{Quote::MAX_CONTAINER_LOADING_ROWS})"
  end

  test "new does not prefill advanced defaults from template settings" do
    template = quote_templates(:one)
    template.update!(
      default_template: true,
      enable_advanced_by_default: true,
      advanced_defaults: {
        "trade_terms_hs_code" => "8703.10",
        "logistics_container_type" => "40HQ"
      },
      advanced_visibility_defaults: {}
    )

    get new_customer_quote_url(@customer)
    assert_response :success
    assert_select "input[name='quote[advanced_mode]'][value='1']", 0
    assert_select "input[name='quote[advanced_trade_terms][hs_code]'][value='8703.10']", 0
    assert_select "input[name='quote[advanced_logistics][container_type]'][value='40HQ']", 0
  end

  test "new keeps advanced mode off when template does not enable advanced defaults" do
    template = quote_templates(:one)
    template.update!(
      default_template: true,
      enable_advanced_by_default: false,
      advanced_defaults: {},
      advanced_visibility_defaults: {}
    )

    get new_customer_quote_url(@customer)
    assert_response :success
    assert_select "input[name='quote[advanced_mode]'][value='1']", 0
  end

  test "new pre-fills business terms from company master preset" do
    preset = @user.company.quote_presets.create!(
      module_key: "business_terms",
      name: "Business Master",
      payload: {
        "payment_term" => "30% TT + 70% before shipment",
        "trade_term" => "FOB Shanghai"
      }
    )
    @user.company.create_quote_preset_master!(
      business_terms_preset: preset
    )

    get new_customer_quote_url(@customer)
    assert_response :success
    assert_select "input[name='quote[payment_term]'][value='30% TT + 70% before shipment']", 1
    assert_select "input[name='quote[trade_term]'][value='FOB Shanghai']", 1
  end

  test "update with advanced mode fills blank advanced blocks from master without overriding existing values" do
    trade_preset = @user.company.quote_presets.create!(
      module_key: "advanced_trade_terms",
      name: "Trade Master",
      payload: {
        "hs_code" => "8703.10",
        "payment_clause_note" => "50% deposit, 50% against B/L copy"
      }
    )
    logistics_preset = @user.company.quote_presets.create!(
      module_key: "advanced_logistics",
      name: "Logistics Master",
      payload: {
        "container_type" => "40HQ",
        "freight_note" => "Ocean freight excluded"
      }
    )
    @user.company.create_quote_preset_master!(
      advanced_trade_terms_preset: trade_preset,
      advanced_logistics_preset: logistics_preset
    )

    patch quote_url(@quote), params: {
      quote: {
        currency: @quote.currency,
        issued_on: @quote.issued_on,
        valid_until: @quote.valid_until,
        payment_term: @quote.payment_term,
        trade_term: @quote.trade_term,
        terms_text: @quote.terms_text,
        delivery_notes: @quote.delivery_notes,
        scope_of_supply: @quote.scope_of_supply,
        advanced_mode: "1",
        advanced_trade_terms: {
          hs_code: "",
          payment_clause_note: "Custom clause by sales"
        },
        advanced_logistics: {
          container_type: "",
          freight_note: ""
        },
        quote_items_attributes: @quote.quote_items.map.with_index do |item, idx|
          [ idx.to_s, { id: item.id, description: item.description, unit_price: item.unit_price, quantity: item.quantity } ]
        end.to_h
      }
    }

    assert_redirected_to quote_url(@quote)
    @quote.reload
    assert_equal "8703.10", @quote.advanced_trade_terms_data["hs_code"]
    assert_equal "Custom clause by sales", @quote.advanced_trade_terms_data["payment_clause_note"]
    assert_equal "40HQ", @quote.advanced_logistics_data["container_type"]
    assert_equal "Ocean freight excluded", @quote.advanced_logistics_data["freight_note"]
  end

  test "show is successful for company quote" do
    get quote_url(@quote)
    assert_response :success
  end

  test "edit keeps advanced section expanded when normalized supplementary data exists" do
    @quote.update!(
      advanced_mode: false,
      advanced_trade_terms: { "hs_code" => "   " },
      advanced_logistics: { "container_type" => "40HQ" }
    )

    get edit_quote_url(@quote)
    assert_response :success
    assert_select "details.quote-form-advanced[open]", 1
  end

  test "internal show uses supplementary wording for advanced sections" do
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    get quote_url(@quote)
    assert_response :success
    assert_includes response.body, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_match(/Shipping (&amp;|&) Logistics/, response.body)
    assert_not_includes response.body, "Advanced Trade Terms"
    assert_not_includes response.body, "Advanced Logistics"
  end

  test "export pdf responds successfully" do
    get export_pdf_quote_url(@quote)
    assert_response :success
  end

  test "export pdf filename prefers quote custom title" do
    @quote.update!(custom_title: "Atlas March Offer")

    get export_pdf_quote_url(@quote)

    assert_response :success
    disposition = response.headers["Content-Disposition"].to_s
    assert_includes disposition, "Atlas March Offer"
    assert_includes disposition, ".pdf"
  end

  test "pdf engine defaults to grover configuration" do
    assert_equal "grover", Rails.configuration.x.quote_pdf.engine
  end

  test "export pdf uses wicked engine when configured" do
    with_env("QUOTE_PDF_ENGINE" => "wicked") do
      get export_pdf_quote_url(@quote)
    end

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.body, "%PDF"
  end

  test "formal closing seller stamp renders stamp image from quote attachment" do
    signature_blob = create_test_image_blob(filename: "seller-stamp.png")
    @quote.seller_stamp_image.attach(signature_blob)
    @quote.update!(
      formal_closing_block: {
        "enabled" => true,
        "seller_stamp_enabled" => true,
        "seller_signature_enabled" => false,
        "buyer_signature_line_enabled" => false
      }
    )

    get quote_url(@quote)
    assert_response :success
    assert_includes response.body, "alt=\"Seller Stamp\""

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success
    assert_includes response.body, "alt=\"Seller Stamp\""

    get public_preview_quote_url(@quote)
    assert_response :success
    assert_includes response.body, "alt=\"Seller Stamp\""
  end

  test "export pdf html uses formal annex section wording" do
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success
    assert_includes response.body, "TRADE TERMS"
    assert_match(/SHIPPING (&amp;|&) LOGISTICS/, response.body)
    assert_not_includes response.body, "SUPPLEMENTARY"
  end

  test "export pdf follows fixed module order when extension blocks are present" do
    detail_blob = create_test_image_blob(filename: "detail-picture-order.png")
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: {
        "hs_code" => "8703.10",
        "payment_clause_note" => "T/T 30% + 70%"
      },
      advanced_logistics: {
        "container_type" => "40HQ",
        "freight_note" => "Port-to-port",
        "container_loading_note" => "2 units / 40HQ"
      },
      container_loading_block: {
        "enabled" => true,
        "rows" => [
          { "variant" => "14 seats", "container_type" => "40HQ", "capacity" => "2 units", "note" => "", "position" => 1 }
        ]
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
      terms_text: "After-sales coverage applies."
    )

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success

    summary_index = response.body.index("TRADE TERMS")
    config_index = response.body.index("CONFIGURATION")
    picture_index = response.body.index("DETAIL PICTURES")
    logistics_index = response.body.index("SHIPPING &amp; LOGISTICS") || response.body.index("SHIPPING & LOGISTICS")
    loading_index = response.body.index("CONTAINER LOADING")
    formal_closing_index = response.body.index("FORMAL CLOSING")

    assert summary_index
    assert config_index
    assert picture_index
    assert logistics_index
    assert loading_index
    assert formal_closing_index
    assert_operator summary_index, :<, config_index
    assert_operator config_index, :<, logistics_index
    assert_operator logistics_index, :<, loading_index
    assert_operator loading_index, :<, picture_index
    assert_operator loading_index, :<, formal_closing_index
    assert_not_includes response.body, I18n.t("quote_document.sections.revision_summary", default: "Revision Summary")
    assert_not_includes response.body, I18n.t("quote_document.sections.company_credentials", default: "Company Credentials")
  end

  test "export pdf keeps full long supplementary text in narrative notes" do
    long_text = Array.new(5, "Warranty covers vehicle body and electric system for 12 months, including remote support and replacement part policy across ports.").join(" ")
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "warranty_scope_note" => long_text },
      advanced_visibility: { "show_trade_terms_advanced" => true }
    )

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success
    assert_includes response.body, "TRADE TERMS"
    assert_includes response.body, long_text
    assert_not_includes response.body, I18n.t("quote_document.sections.commercial_notes", default: "Commercial Notes")
  end

  test "export pdf renders container loading matrix when structured rows exist" do
    @quote.update!(
      advanced_mode: true,
      advanced_visibility: {
        "show_logistics_block" => true
      },
      container_loading_block: {
        "enabled" => true,
        "rows" => [
          { "variant" => "14 seats without windows", "container_type" => "40HQ", "capacity" => "4 units", "note" => "", "position" => 1 },
          { "variant" => "14 seats with windows", "container_type" => "40HQ", "capacity" => "2 units", "note" => "DG applies", "position" => 2 }
        ]
      },
      advanced_logistics: {
        "container_loading_note" => "legacy fallback note"
      }
    )

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success
    assert_includes response.body, "quote-mini-table--container-loading"
    assert_includes response.body, "14 seats without windows"
    assert_not_includes response.body, ">legacy fallback note<"
  end

  test "export pdf renders detail pictures as 2-column annex table and skips empty captions" do
    detail_blob_a = create_test_image_blob(filename: "detail-a.png")
    detail_blob_b = create_test_image_blob(filename: "detail-b.png")
    @quote.update!(
      advanced_mode: true,
      detail_pictures_block: {
        "enabled" => true,
        "items" => [
          { "image_blob_id" => detail_blob_a.id.to_s, "caption" => "", "source" => "product_gallery", "position" => 1 },
          { "image_blob_id" => detail_blob_b.id.to_s, "caption" => "Controller panel", "source" => "quote_upload", "position" => 2 }
        ]
      }
    )

    get export_pdf_quote_url(@quote, params: { debug: 1 })
    assert_response :success
    assert_includes response.body, "pdf-detail-table"
    assert_includes response.body, "pdf-detail-keep-first"
    assert_includes response.body, "quote-detail-picture-image"
    assert_not_includes response.body, "<figcaption class=\"quote-detail-picture-caption\"></figcaption>"
  end

  test "disabling extended mode does not delete stored advanced data" do
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: { "show_trade_terms_advanced" => true, "show_logistics_block" => true }
    )

    patch quote_url(@quote), params: {
      quote: {
        currency: @quote.currency,
        issued_on: @quote.issued_on,
        valid_until: @quote.valid_until,
        payment_term: @quote.payment_term,
        trade_term: @quote.trade_term,
        terms_text: @quote.terms_text,
        delivery_notes: @quote.delivery_notes,
        scope_of_supply: @quote.scope_of_supply,
        advanced_mode: "0",
        quote_items_attributes: @quote.quote_items.map.with_index do |item, idx|
          [ idx.to_s, { id: item.id, description: item.description, unit_price: item.unit_price, quantity: item.quantity } ]
        end.to_h
      }
    }

    assert_redirected_to quote_url(@quote)
    @quote.reload
    assert_equal false, @quote.advanced_mode
    assert_equal "8703.10", @quote.advanced_trade_terms["hs_code"]
    assert_equal "40HQ", @quote.advanced_logistics["container_type"]
  end

  test "export xlsx responds successfully" do
    get export_xlsx_quote_url(@quote)
    assert_response :success
  end

  test "export xlsx filename prefers quote custom title" do
    @quote.update!(custom_title: "Atlas March Offer")

    get export_xlsx_quote_url(@quote)

    assert_response :success
    disposition = response.headers["Content-Disposition"].to_s
    assert_includes disposition, "Atlas March Offer"
    assert_includes disposition, ".xlsx"
  end

  test "public preview uses customer-facing supplementary wording" do
    @quote.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_logistics: { "container_type" => "40HQ" },
      advanced_visibility: {
        "show_trade_terms_advanced" => true,
        "show_logistics_block" => true
      }
    )

    get public_preview_quote_url(@quote)
    assert_response :success
    assert_includes response.body, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_match(/Shipping (&amp;|&) Logistics/, response.body)
    assert_not_includes response.body, "Advanced Trade Terms"
    assert_not_includes response.body, "Advanced Logistics"
  end

  test "share creates public token and redirects" do
    quote = build_shareable_quote
    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["RAILS_PROTOCOL"]
    ENV["APP_HOST"] = "www.example.com"
    ENV["RAILS_PROTOCOL"] = "http"

    assert_difference("QuoteShare.count", 1) do
      post share_quote_url(quote)
    end

    assert_response :redirect
    assert_match(%r{/public/quote_shares/}, response.headers["Location"])
  ensure
    ENV["APP_HOST"] = previous_host
    ENV["RAILS_PROTOCOL"] = previous_protocol
  end

  test "create_pi creates independent pi quote and links source relation" do
    source_template = quote_templates(:one)
    source_template.dup.tap do |pi_template|
      pi_template.name = "PI Template #{SecureRandom.hex(3)}"
      pi_template.slug = "pi-template-#{SecureRandom.hex(4)}"
      pi_template.default_template = false
      pi_template.document_kind = "proforma_invoice"
      pi_template.save!
    end

    created_pi_quote = nil
    assert_difference("Quote.count", 1) do
      post create_pi_quote_url(@quote)
      created_pi_quote = Quote.order(:created_at).last
    end

    assert_redirected_to quote_url(created_pi_quote, doc: "pi", document_kind: "pi")
    assert_equal @quote.id, created_pi_quote.source_quote_id
    assert created_pi_quote.pi_document?
    assert_equal "proforma_invoice", created_pi_quote.template.document_kind
    assert_equal @quote.customer_id, created_pi_quote.customer_id
    assert_equal @quote.quote_items.count, created_pi_quote.quote_items.count

    get quote_url(@quote)
    assert_response :success
    assert_includes response.body, I18n.t("quotes.view.show.related_documents_title")
    assert_includes response.body, "[PI]"
    assert_not_includes response.body, "Confirm PI-specific fields before creating an independent PI document."

    assert_no_difference("Quote.count") do
      post create_pi_quote_url(@quote)
    end
    assert_redirected_to quote_url(created_pi_quote, doc: "pi", document_kind: "pi")
    assert_equal I18n.t("quotes.flash.pi_opened_existing"), flash[:notice]
  end

  test "create_pi is blocked for source-linked pi quote" do
    pi_quote = Quote.create!(
      company: @quote.company,
      customer: @quote.customer,
      template: @quote.template,
      source_quote: @quote,
      currency: @quote.currency,
      issued_on: Date.current,
      status: "draft",
      quote_items_attributes: [ { description: "PI row", unit_price: 10, quantity: 1 } ]
    )

    assert_no_difference("Quote.count") do
      post create_pi_quote_url(pi_quote)
    end
    assert_redirected_to quote_url(pi_quote)
    assert_equal I18n.t("quotes.flash.pi_generation_not_available"), flash[:alert]
  end

  test "pi update only persists editable pi fields" do
    post create_pi_quote_url(@quote)
    pi_quote = Quote.order(:created_at).last
    original_currency = pi_quote.currency
    original_tax_amount = pi_quote.tax_amount
    original_item_description = pi_quote.quote_items.first.description

    patch quote_url(pi_quote), params: {
      quote: {
        custom_title: "PI Custom Title",
        valid_until: Date.current + 20.days,
        payment_term: "T/T 50/50",
        trade_term: "CIF Hamburg",
        delivery_notes: "Delivery in 45 days",
        notes: "PI notes",
        terms_text: "PI terms",
        legal_disclaimer: "PI legal",
        scope_of_supply: "PI scope",
        currency: "CNY",
        tax_amount: 999,
        quote_items_attributes: {
          "0" => {
            id: pi_quote.quote_items.first.id,
            description: "Mutated row",
            unit_price: 999
          }
        },
        formal_closing_block: {
          pi_number: "PI-LOCK-0001",
          bank_route: "BANK ROUTE A",
          beneficiary_details: "BENEFICIARY A",
          remittance_note: "REMIT NOTE A",
          buyer_signature_line_enabled: "1"
        }
      }
    }

    assert_redirected_to quote_url(pi_quote)
    pi_quote.reload
    assert_equal "PI Custom Title", pi_quote.custom_title
    assert_equal "T/T 50/50", pi_quote.payment_term
    assert_equal "CIF Hamburg", pi_quote.trade_term
    assert_equal "Delivery in 45 days", pi_quote.delivery_notes
    assert_equal "PI notes", pi_quote.notes
    assert_equal "PI terms", pi_quote.terms_text
    assert_equal "PI legal", pi_quote.legal_disclaimer
    assert_equal "PI scope", pi_quote.scope_of_supply
    assert_equal "PI-LOCK-0001", pi_quote.formal_closing_block_data["pi_number"]
    assert_equal "BANK ROUTE A", pi_quote.formal_closing_block_data["bank_route"]
    assert_equal original_currency, pi_quote.currency
    assert_equal original_tax_amount, pi_quote.tax_amount
    assert_equal original_item_description, pi_quote.quote_items.first.description
  end

  test "pi show hides quote workflow controls and decision modules" do
    post create_pi_quote_url(@quote)
    pi_quote = Quote.order(:created_at).last

    get quote_url(pi_quote, doc: "pi", document_kind: "pi")
    assert_response :success
    assert_not_includes response.body, I18n.t("quotes.view.decision_review.title")
    assert_not_includes response.body, I18n.t("quotes.view.decision_timeline.title")
    assert_not_includes response.body, I18n.t("quotes.view.show.engagement_details")
    assert_not_includes response.body, I18n.t("quotes.view.show.toolbar.delete_quote")
    assert_includes response.body, I18n.t("quotes.view.show.toolbar.export")
    assert_not_includes response.body, I18n.t("quotes.view.show.toolbar.send_share")
  end

  test "share returns json url" do
    quote = build_shareable_quote

    assert_difference("QuoteShare.count", 1) do
      post share_quote_url(quote, format: :json)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_match(%r{/public/quote_shares/}, payload["url"])
  end

  test "share json uses trusted configured host when present" do
    quote = build_shareable_quote
    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["RAILS_PROTOCOL"]
    ENV["APP_HOST"] = "trusted.example.com"
    ENV["RAILS_PROTOCOL"] = "https"

    assert_difference("QuoteShare.count", 1) do
      post share_quote_url(quote, format: :json)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_match(%r{\Ahttps://trusted\.example\.com/public/quote_shares/}, payload["url"])
  ensure
    ENV["APP_HOST"] = previous_host
    ENV["RAILS_PROTOCOL"] = previous_protocol
  end

  test "send reminder delivers email and updates counters" do
    @quote.customer.update!(email: "buyer@example.com")
    @quote.company.update!(
      reminder_email_subject: "Follow up: %{quote_no}",
      reminder_email_body: "Hello %{customer_name}, please review %{quote_no} from %{company_name}.",
      reminder_email_cta_label: "Review quote"
    )
    @quote.update!(status: "sent", sent_at: 3.days.ago, viewed_at: nil)

    previous_skip = ENV["SKIP_TURNSTILE_VERIFICATION"]
    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["RAILS_PROTOCOL"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"
    ENV["APP_HOST"] = "trusted.example.com"
    ENV["RAILS_PROTOCOL"] = "https"
    begin
      assert_emails 1 do
        post send_reminder_quote_url(@quote)
      end

      assert_redirected_to quote_url(@quote)
      @quote.reload
      email = ActionMailer::Base.deliveries.last
      assert_equal "Follow up: #{@quote.quote_no}", email.subject
      assert_includes email.body.encoded, "Hello #{@quote.customer.name}, please review #{@quote.quote_no} from #{@quote.company.name}."
      assert_includes email.body.encoded, "Review quote"
      assert_includes email.body.encoded, "https://trusted.example.com/public/quote_shares/"
      assert_equal 1, @quote.reminder_count
      assert @quote.reminder_sent_at.present?
    ensure
      if previous_skip.nil?
        ENV.delete("SKIP_TURNSTILE_VERIFICATION")
      else
        ENV["SKIP_TURNSTILE_VERIFICATION"] = previous_skip
      end
      ENV["APP_HOST"] = previous_host
      ENV["RAILS_PROTOCOL"] = previous_protocol
    end
  end

  test "update_outcome_reason updates win reason for won quote" do
    @quote.update_columns(status: "won", win_reason: nil, win_reason_detail: nil)

    patch update_outcome_reason_quote_url(@quote), params: {
      quote: {
        win_reason: "price_accepted",
        win_reason_detail: "Accepted after final call"
      }
    }

    assert_redirected_to quote_url(@quote)
    @quote.reload
    assert_equal "price_accepted", @quote.win_reason
    assert_equal "Accepted after final call", @quote.win_reason_detail
  end

  test "update_outcome_reason rejects non won_or_lost quote" do
    @quote.update_columns(status: "sent", win_reason: nil, win_reason_detail: nil)

    patch update_outcome_reason_quote_url(@quote), params: {
      quote: {
        win_reason: "price_accepted"
      }
    }

    assert_redirected_to quote_url(@quote)
    @quote.reload
    assert_nil @quote.win_reason
  end

  private

  def with_env(vars)
    backup = vars.transform_values { nil }
    vars.each_key { |key| backup[key] = ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    backup.each { |key, value| ENV[key] = value }
  end

  def build_shareable_quote
    Quote.create!(
      company: @user.company,
      customer: @customer,
      quote_no: "QT-SHARE-#{SecureRandom.hex(4).upcase}",
      currency: "USD",
      status: "draft",
      issued_on: Date.current,
      quote_items_attributes: [ { description: "Share Item", unit_price: 100, quantity: 1 } ]
    )
  end

  def create_test_image_blob(filename: "detail-picture.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake image content"),
      filename: filename,
      content_type: "image/png"
    )
  end
end
