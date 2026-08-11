require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "registration preserves the visible account fields" do
    previous_skip = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          username: "new_quote_seller",
          email: "new-quote-seller@example.com",
          password: "secure-password-2026",
          password_confirmation: "secure-password-2026"
        }
      }
    end

    user = User.find_by!(username: "new_quote_seller")
    assert_equal "new-quote-seller@example.com", user.email
    assert user.valid_password?("secure-password-2026")
  ensure
    ENV["SKIP_TURNSTILE_VERIFICATION"] = previous_skip
  end
end
