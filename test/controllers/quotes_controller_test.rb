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

  test "new pre-fills advanced defaults when template enables advanced by default" do
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
    assert_select "input[name='quote[advanced_mode]'][checked='checked']", 1
    assert_select "input[name='quote[advanced_trade_terms][hs_code]'][value='8703.10']", 1
    assert_select "input[name='quote[advanced_logistics][container_type]'][value='40HQ']", 1
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
    assert_select "input[name='quote[advanced_mode]'][checked='checked']", 0
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

  test "export pdf html uses customer-facing supplementary wording" do
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
    assert_includes response.body, I18n.t("quotes.view.show.supplementary_trade_terms", default: "Supplementary Trade Terms")
    assert_match(/Shipping (&amp;|&) Logistics/, response.body)
    assert_not_includes response.body, "Advanced Trade Terms"
    assert_not_includes response.body, "Advanced Logistics"
  end

  test "export xlsx responds successfully" do
    get export_xlsx_quote_url(@quote)
    assert_response :success
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
end
