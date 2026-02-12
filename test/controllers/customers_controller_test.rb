require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @customer = customers(:one)
    sign_in @user
  end

  test "index is successful" do
    get customers_url
    assert_response :success
  end

  test "show is successful for company customer" do
    get customer_url(@customer)
    assert_response :success
  end
end
