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
end
