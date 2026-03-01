require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @user.update!(
      email_verified_at: nil,
      email_verification_token: nil,
      email_verification_token_sent_at: nil
    )
  end

  test "resend works for signed out user with email param" do
    previous = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    assert_changes -> { @user.reload.email_verification_token.present? }, from: false, to: true do
      post resend_email_verifications_path, params: { email: @user.email }
      assert_response :success
    end

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
  ensure
    ENV["SKIP_TURNSTILE_VERIFICATION"] = previous
  end

  test "resend returns generic success for unknown email" do
    previous = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    post resend_email_verifications_path, params: { email: "nobody@example.com" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_match(/If an account with that email exists/i, body["message"])
  ensure
    ENV["SKIP_TURNSTILE_VERIFICATION"] = previous
  end

  test "resend for verified signed in user returns already verified message" do
    previous = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"
    @user.update!(email_verified_at: Time.current)
    sign_in @user

    post resend_email_verifications_path
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_match(/already verified/i, body["message"])
  ensure
    ENV["SKIP_TURNSTILE_VERIFICATION"] = previous
  end
end
