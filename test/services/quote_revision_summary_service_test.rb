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
end
