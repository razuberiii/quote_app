require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  test "build_revision keeps trade term and item structured data" do
    quote = quotes(:one)
    quote.trade_term = "FOB Shanghai"
    first_item = quote.quote_items.first
    first_item.update!(
      specifications: [ { key: "Power", value: "5kW" } ],
      addon_charges: [ { name: "Packaging", amount: "25.00" } ]
    )

    revision = quote.build_revision

    assert_equal "FOB Shanghai", revision.trade_term
    assert_equal first_item.specifications, revision.quote_items.first.specifications
    assert_equal first_item.addon_charges, revision.quote_items.first.addon_charges
  end

  test "lost status requires loss reason" do
    quote = quotes(:one)
    quote.status = "lost"
    quote.loss_reason = ""

    assert_not quote.valid?
    assert_includes quote.errors[:loss_reason], "is required when quote status is Lost"
  end

  test "won status auto-fills final amount from grand total when blank" do
    quote = quotes(:one)
    quote.status = "won"
    quote.win_reason = "price_accepted"
    quote.final_amount = nil

    assert quote.valid?
    assert_equal quote.grand_total, quote.final_amount
  end

  test "build_revision copies snapshot fields" do
    item = quote_items(:one)
    item.update!(
      specifications: [ { key: "Power", value: "5kW" } ],
      addon_charges: [ { name: "Packaging", amount: "25.00" } ],
      spec_snapshot: [ { key: "Power", value: "5kW" } ],
      addon_snapshot: [ { name: "Packaging", amount: "25.00" } ]
    )

    revision = quotes(:one).build_revision

    assert_equal item.spec_snapshot, revision.quote_items.first.spec_snapshot
    assert_equal item.addon_snapshot, revision.quote_items.first.addon_snapshot
  end

  test "can_send_reminder only after 48 hours when quote is still not viewed" do
    quote = quotes(:one)
    quote.update!(status: "sent", sent_at: 49.hours.ago, viewed_at: nil)

    assert quote.can_send_reminder?

    quote.update!(viewed_at: Time.current)
    assert_not quote.can_send_reminder?
  end

  test "won status still requires standardized win reason even when detail is present" do
    quote = quotes(:one)
    quote.status = "won"
    quote.win_reason = nil
    quote.win_reason_detail = "Client trusted our faster delivery"

    assert_not quote.valid?
    assert_includes quote.errors[:win_reason], "is required when quote status is Won"
  end

  test "lost status still requires standardized loss reason even when detail is present" do
    quote = quotes(:one)
    quote.status = "lost"
    quote.loss_reason = nil
    quote.loss_reason_detail = "Buyer postponed project internally"

    assert_not quote.valid?
    assert_includes quote.errors[:loss_reason], "is required when quote status is Lost"
  end

  test "reason option pairs keep defaults and append company dictionary entries" do
    skip "quote_reason_options table missing" unless defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?

    company = companies(:one)
    company.quote_reason_options.create!(kind: "win", key: "fast_delivery", label: "Fast Delivery")

    pairs = Quote.reason_option_pairs_for(:win, company: company)

    assert_includes pairs, [ "Fast Delivery", "fast_delivery" ]
    assert_includes pairs, [ I18n.t("analytics.reason_labels.win.price_accepted", default: "Price accepted"), "price_accepted" ]
  end

  test "display win reason prefers company dictionary label" do
    skip "quote_reason_options table missing" unless defined?(QuoteReasonOption) && QuoteReasonOption.table_exists?

    quote = quotes(:one)
    quote.company.quote_reason_options.create!(kind: "win", key: "faster_delivery", label: "Faster Delivery")
    quote.win_reason = "faster_delivery"

    assert_equal "Faster Delivery", quote.display_win_reason
  end

  test "advanced visibility derives from quote values and explicit quote flags only" do
    quote = Quote.new(
      company: companies(:one),
      customer: customers(:one),
      template: quote_templates(:one),
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      advanced_trade_terms: { "hs_code" => "8703.10" }
    )
    quote.quote_items.build(description: "Item A", quantity: 1, unit_price: 100)

    visibility = quote.advanced_visibility_data
    assert_equal true, visibility["show_trade_terms_advanced"]
    assert_equal false, visibility["show_logistics_block"]
    assert_not quote.advanced_section_enabled?("show_trade_terms_advanced")

    quote.advanced_mode = true
    quote.advanced_visibility = { "show_logistics_block" => true }
    visibility = quote.advanced_visibility_data
    assert_equal true, visibility["show_trade_terms_advanced"]
    assert_equal true, visibility["show_logistics_block"]
    assert quote.advanced_section_enabled?("show_trade_terms_advanced")
    assert quote.advanced_section_enabled?("show_logistics_block")
  end

  test "advanced section open state follows normalized non-empty values only" do
    quote = Quote.new(
      company: companies(:one),
      customer: customers(:one),
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      advanced_trade_terms: {
        "hs_code" => "   ",
        "support_scope_note" => ""
      },
      advanced_logistics: {
        "container_type" => "40HQ"
      }
    )
    quote.quote_items.build(description: "Item A", quantity: 1, unit_price: 100)

    assert quote.advanced_sections_have_values?
    assert_equal({ "container_type" => "40HQ" }, quote.advanced_logistics_data)
    assert_equal({}, quote.advanced_trade_terms_data)
  end

  test "quote does not inject demo defaults when fields are blank" do
    quote = Quote.new(
      company: companies(:one),
      customer: customers(:one),
      template: quote_templates(:one),
      currency: "USD",
      issued_on: Date.current,
      status: "draft"
    )
    quote.quote_items.build(description: "Item A", quantity: 1, unit_price: 100)

    assert quote.valid?
    assert_nil quote.payment_term
    assert_nil quote.scope_of_supply
    assert_equal false, quote.advanced_mode
  end

  test "pi document detection treats source-linked quote as pi profile" do
    source_quote = quotes(:one)
    pi_quote = Quote.create!(
      company: source_quote.company,
      customer: source_quote.customer,
      template: source_quote.template,
      source_quote: source_quote,
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      quote_items_attributes: [ { description: "PI Line", unit_price: 100, quantity: 1 } ]
    )

    assert pi_quote.pi_document?
    assert_not pi_quote.can_generate_pi?
  end

  test "source quote can only have one pi quote" do
    source_quote = quotes(:one)
    Quote.create!(
      company: source_quote.company,
      customer: source_quote.customer,
      template: source_quote.template,
      source_quote: source_quote,
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      quote_items_attributes: [ { description: "PI One", unit_price: 100, quantity: 1 } ]
    )

    duplicate = Quote.new(
      company: source_quote.company,
      customer: source_quote.customer,
      template: source_quote.template,
      source_quote: source_quote,
      currency: "USD",
      issued_on: Date.current,
      status: "draft"
    )
    duplicate.quote_items.build(description: "PI Two", unit_price: 120, quantity: 1)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:source_quote_id, :taken, value: source_quote.id)
  end

  test "pi quote can still be edited when status is not draft" do
    source_quote = quotes(:one)
    pi_quote = Quote.create!(
      company: source_quote.company,
      customer: source_quote.customer,
      template: source_quote.template,
      source_quote: source_quote,
      currency: "USD",
      issued_on: Date.current,
      status: "sent",
      quote_items_attributes: [ { description: "PI editable", unit_price: 100, quantity: 1 } ]
    )

    assert pi_quote.pi_document?
    assert pi_quote.can_edit_revision?
  end

  test "excluding_pi_documents scope keeps only operational quote documents" do
    source_quote = quotes(:one)
    pi_quote = Quote.create!(
      company: source_quote.company,
      customer: source_quote.customer,
      template: source_quote.template,
      source_quote: source_quote,
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      quote_items_attributes: [ { description: "PI scope", unit_price: 100, quantity: 1 } ]
    )

    scoped_ids = source_quote.company.quotes.excluding_pi_documents.pluck(:id)

    assert_includes scoped_ids, source_quote.id
    assert_not_includes scoped_ids, pi_quote.id
  end

  test "configuration block follows quote override and explicit empty protects against lower layers" do
    quote = quotes(:one)
    quote.configuration_block = {
      "rows" => [],
      "notes" => ""
    }

    product_block = {
      "rows" => [ { "label" => "Motor", "value" => "72V 7.5kW", "source" => "product", "position" => 1 } ],
      "notes" => "Product fallback note"
    }

    resolved = quote.configuration_block_data(product_block: product_block, fallback_block: {})

    assert_equal [], resolved["rows"]
    assert_nil resolved["notes"]
  end

  test "detail pictures block keeps quote-specific items over product defaults" do
    quote = quotes(:one)
    quote.detail_pictures_block = {
      "enabled" => true,
      "items" => [
        { "image_blob_id" => "9001", "caption" => "Quote specific", "source" => "quote_upload", "position" => 1 }
      ]
    }

    product_block = {
      "enabled" => true,
      "items" => [
        { "image_blob_id" => "3001", "caption" => "Product image", "source" => "product_gallery", "position" => 1 }
      ]
    }

    resolved = quote.detail_pictures_block_data(product_block: product_block)

    assert_equal true, resolved["enabled"]
    assert_equal "9001", resolved["items"].first["image_blob_id"]
    assert_equal "quote_upload", resolved["items"].first["source"]
  end

  test "configuration block keeps minimal label-value-position rows only" do
    quote = quotes(:one)
    quote.configuration_block = {
      "enabled" => true,
      "rows" => [
        { "label" => "Motor", "value" => "72V", "position" => 2 },
        { "label" => "", "value" => "invalid", "position" => 1 },
        { "key" => "Controller", "value" => "Curtis", "position" => 1 }
      ]
    }

    assert quote.valid?
    rows = quote.configuration_block_data["rows"]
    assert_equal 2, rows.size
    assert_equal "Controller", rows.first["label"]
    assert_equal "Motor", rows.last["label"]
  end

  test "detail pictures block supports mixed sources with unified order" do
    quote = quotes(:one)
    blob_a = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("a"), filename: "a.png", content_type: "image/png")
    blob_b = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("b"), filename: "b.png", content_type: "image/png")

    quote.detail_pictures_block = {
      "enabled" => true,
      "items" => [
        { "image_blob_id" => blob_b.id.to_s, "caption" => "Quote Upload", "source" => "quote_upload", "position" => 2 },
        { "image_blob_id" => blob_a.id.to_s, "caption" => "Product Gallery", "source" => "product_gallery", "position" => 1 }
      ]
    }

    assert quote.valid?
    items = quote.detail_pictures_block_data["items"]
    assert_equal 2, items.size
    assert_equal "product_gallery", items.first["source"]
    assert_equal "quote_upload", items.last["source"]
  end

  test "detail pictures block validates max item count" do
    quote = quotes(:one)
    quote.detail_pictures_block = {
      "enabled" => true,
      "items" => Array.new(Quote::MAX_DETAIL_PICTURES_ITEMS + 1) do |idx|
        { "image_blob_id" => (idx + 1).to_s, "caption" => "Image #{idx}", "source" => "quote_upload", "position" => idx + 1 }
      end
    }

    assert_not quote.valid?
    assert_includes quote.errors[:detail_pictures_block], "items exceed limit (#{Quote::MAX_DETAIL_PICTURES_ITEMS})"
  end

  test "detail pictures block validates referenced blob existence" do
    quote = quotes(:one)
    quote.detail_pictures_block = {
      "enabled" => true,
      "items" => [
        { "image_blob_id" => "999999", "caption" => "Missing image", "source" => "quote_upload", "position" => 1 }
      ]
    }

    assert_not quote.valid?
    assert_includes quote.errors[:detail_pictures_block], "contains missing images"
  end

  test "container loading block keeps lightweight rows sorted by position" do
    quote = quotes(:one)
    quote.container_loading_block = {
      "enabled" => true,
      "rows" => [
        { "variant" => "14 seats with windows", "container_type" => "40HQ", "capacity" => "2 units", "note" => "", "position" => 2 },
        { "variant" => "14 seats without windows", "container_type" => "40HQ", "capacity" => "4 units", "note" => "", "position" => 1 },
        { "variant" => "", "container_type" => "", "capacity" => "", "note" => "", "position" => 3 }
      ]
    }

    assert quote.valid?
    rows = quote.container_loading_block_data["rows"]
    assert_equal 2, rows.size
    assert_equal "14 seats without windows", rows.first["variant"]
    assert_equal "14 seats with windows", rows.last["variant"]
  end

  test "container loading block validates max row count" do
    quote = quotes(:one)
    quote.container_loading_block = {
      "enabled" => true,
      "rows" => Array.new(Quote::MAX_CONTAINER_LOADING_ROWS + 1) do |idx|
        { "variant" => "Variant #{idx}", "container_type" => "40HQ", "capacity" => "2", "note" => "", "position" => idx + 1 }
      end
    }

    assert_not quote.valid?
    assert_includes quote.errors[:container_loading_block], "rows exceed limit (#{Quote::MAX_CONTAINER_LOADING_ROWS})"
  end

  test "buyer locale is limited to supported customer languages" do
    quote = quotes(:one)
    Quote::BUYER_LOCALES.each do |locale|
      quote.buyer_locale = locale
      assert quote.valid?, "expected #{locale} to be accepted"
    end

    quote.buyer_locale = "fr"
    assert_not quote.valid?
    assert_includes quote.errors[:buyer_locale], "is not included in the list"
  end

  test "published snapshot keeps the buyer locale" do
    quote = quotes(:one)
    quote.buyer_locale = "es-419"

    assert_equal "es-419", QuoteSnapshotBuilder.new(quote).as_json["buyer_locale"]
  end
end
