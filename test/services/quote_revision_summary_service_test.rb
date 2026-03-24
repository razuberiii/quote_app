require "test_helper"

class QuoteRevisionSummaryServiceTest < ActiveSupport::TestCase
  test "returns lightweight summary when revision has meaningful changes" do
    original = quotes(:one)
    revised = original.build_revision
    revised.quote_items.first.quantity = original.quote_items.first.quantity + 2
    revised.save!

    summary = QuoteRevisionSummaryService.new(quote: revised).call

    assert summary.present?
    assert_equal original.revision_number, summary[:previous_revision_number]
    assert_equal revised.revision_number, summary[:current_revision_number]
    assert summary[:lines].any?
  end

  test "summary uses customer-facing labels for advanced key-level changes" do
    original = quotes(:one)
    original.update!(
      advanced_mode: true,
      advanced_trade_terms: { "hs_code" => "8703.10" },
      advanced_visibility: { "show_trade_terms_advanced" => true }
    )

    revised = original.build_revision
    revised.advanced_trade_terms = { "hs_code" => "8703.20" }
    revised.save!

    summary = QuoteRevisionSummaryService.new(quote: revised).call

    assert summary.present?
    assert summary[:lines].any? { |line| line.include?(I18n.t("quotes.view.form.hs_code", default: "HS Code")) }
    assert summary[:lines].none? { |line| line.include?("Advanced Trade Terms") }
  end

  test "summary keeps key-level and section-level without duplicate generic only signal" do
    original = quotes(:one)
    original.update!(
      advanced_mode: true,
      advanced_trade_terms: {
        "hs_code" => "8703.10",
        "support_scope_note" => "Remote support"
      },
      advanced_visibility: { "show_trade_terms_advanced" => true }
    )

    revised = original.build_revision
    revised.advanced_trade_terms = {
      "hs_code" => "8703.20",
      "support_scope_note" => "Local support"
    }
    revised.save!

    summary = QuoteRevisionSummaryService.new(quote: revised).call
    lines = summary[:lines]

    hs_label = I18n.t("quotes.view.form.hs_code", default: "HS Code")
    section_label = I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_equal 1, lines.count { |line| line.include?(hs_label) }
    assert_equal 1, lines.count { |line| line.include?(section_label) }
  end
end
