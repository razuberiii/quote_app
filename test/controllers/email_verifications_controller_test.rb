require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @user.update!(
      email_verified_at: nil,
      email_verification_code_digest: nil,
      email_verification_code_sent_at: nil,
      email_verification_attempts: 0
    )
  end

  test "resend works for signed out user with email param" do
    previous = ENV["SKIP_TURNSTILE_VERIFICATION"]
    ENV["SKIP_TURNSTILE_VERIFICATION"] = "true"

    assert_changes -> { @user.reload.email_verification_code_digest.present? }, from: false, to: true do
      post resend_email_verifications_path, params: { email: @user.email }
      assert_response :success
    end

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_equal EmailVerificationService::RESEND_COOLDOWN_SECONDS, body["cooldown"]
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
    assert_match(/如果该邮箱对应账户存在/, body["message"])
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

  test "verify marks user as verified when code matches" do
    service = EmailVerificationService.new(@user)
    digest = service.send(:digest_for, "123456")
    @user.update!(
      email_verification_code_digest: digest,
      email_verification_code_sent_at: Time.current,
      email_verification_attempts: 0
    )

    post verify_email_verifications_path, params: { email: @user.email, code: "123456" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert @user.reload.email_verified?
  end
end
