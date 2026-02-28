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
end
