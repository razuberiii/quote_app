require_relative "application_system_test_case"

class ReminderQueueTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @quote = quotes(:one)
    @quote.update!(status: "sent", sent_at: 3.days.ago, viewed_at: nil)
  end

  test "quote detail shows reminder button for eligible quote" do
    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    visit quote_path(@quote)

    assert_button "Send Reminder"
  end
end
