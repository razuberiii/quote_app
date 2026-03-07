require "test_helper"

class PublicQuoteSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @quote = quotes(:one)
    @quote.update!(status: "sent", sent_at: 3.days.ago, viewed_at: nil)
    @share = QuoteShare.create!(company: @quote.company, quote: @quote, token: QuoteShare.generate_token, snapshot: QuoteSnapshotBuilder.new(@quote).as_json)
  end

  test "request revision persists reason and message" do
    post request_revision_public_quote_share_url(@share.token), params: {
      request_reason: "specification change",
      client_message: "Need a lower voltage option"
    }

    assert_response :redirect
    assert_match(%r{/public/quote_shares/#{@share.token}}, response.headers["Location"])
    @quote.reload
    assert_equal "specification change", @quote.request_reason
    assert_equal "Need a lower voltage option", @quote.changes_request_message
    assert_equal "negotiating", @quote.status
  end
end
