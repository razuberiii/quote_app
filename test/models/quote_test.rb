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

  test "advanced visibility derives from template defaults and explicit quote flags" do
    template = quote_templates(:one)
    template.update!(
      enable_advanced_by_default: true,
      advanced_defaults: { "trade_terms_hs_code" => "8703.10" },
      advanced_visibility_defaults: {}
    )

    quote = Quote.new(
      company: companies(:one),
      customer: customers(:one),
      template: template,
      currency: "USD",
      issued_on: Date.current,
      status: "draft"
    )
    quote.quote_items.build(description: "Item A", quantity: 1, unit_price: 100)

    visibility = quote.advanced_visibility_data(template: template)
    assert_equal true, visibility["show_trade_terms_advanced"]
    assert_equal false, visibility["show_logistics_block"]
    assert_not quote.advanced_section_enabled?("show_trade_terms_advanced", template: template)

    quote.advanced_mode = true
    quote.advanced_visibility = { "show_logistics_block" => true }
    visibility = quote.advanced_visibility_data(template: template)
    assert_equal true, visibility["show_trade_terms_advanced"]
    assert_equal true, visibility["show_logistics_block"]
    assert quote.advanced_section_enabled?("show_trade_terms_advanced", template: template)
    assert quote.advanced_section_enabled?("show_logistics_block", template: template)
  end

  test "explicitly cleared advanced value blocks template default refill" do
    template = quote_templates(:one)
    template.update!(
      enable_advanced_by_default: true,
      advanced_defaults: { "trade_terms_hs_code" => "8703.10" },
      advanced_visibility_defaults: {}
    )

    quote = Quote.new(
      company: companies(:one),
      customer: customers(:one),
      template: template,
      currency: "USD",
      issued_on: Date.current,
      status: "draft",
      advanced_trade_terms: { "hs_code" => "" }
    )
    quote.quote_items.build(description: "Item A", quantity: 1, unit_price: 100)

    quote.apply_template_advanced_defaults!

    assert_equal "", quote.advanced_trade_terms["hs_code"]
    assert_equal({}, quote.advanced_trade_terms_data)
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
end
