require "test_helper"

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

  test "show is successful for company quote" do
    get quote_url(@quote)
    assert_response :success
  end

  test "export pdf responds successfully" do
    get export_pdf_quote_url(@quote)
    assert_response :success
  end

  test "export xlsx responds successfully" do
    get export_xlsx_quote_url(@quote)
    assert_response :success
  end

  test "share creates public token and redirects" do
    assert_difference("QuoteShare.count", 1) do
      post share_quote_url(@quote)
    end

    assert_response :redirect
    assert_match(%r{/public/quote_shares/}, response.headers["Location"])
  end

  test "share returns json url" do
    assert_difference("QuoteShare.count", 1) do
      post share_quote_url(@quote, format: :json)
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_match(%r{/public/quote_shares/}, payload["url"])
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
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"
    begin
      assert_emails 1 do
        post send_reminder_quote_url(@quote)
      end
    ensure
      if previous_skip.nil?
        ENV.delete("SKIP_TURNSTILE_VERIFICATION")
      else
        ENV["SKIP_TURNSTILE_VERIFICATION"] = previous_skip
      end
    end

    assert_redirected_to quote_url(@quote)
    @quote.reload
    email = ActionMailer::Base.deliveries.last
    assert_equal "Follow up: #{@quote.quote_no}", email.subject
    assert_includes email.body.encoded, "Hello #{@quote.customer.name}, please review #{@quote.quote_no} from #{@quote.company.name}."
    assert_includes email.body.encoded, "Review quote"
    assert_equal 1, @quote.reminder_count
    assert @quote.reminder_sent_at.present?
  end
end
