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
end
