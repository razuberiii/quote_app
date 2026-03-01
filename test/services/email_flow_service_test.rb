require "test_helper"

class EmailFlowServiceTest < ActiveSupport::TestCase
  class UpdateFailingUser
    attr_reader :id

    def initialize(id: 0)
      @id = id
    end

    def blank?
      false
    end

    def update(*)
      false
    end

    def email_verification_token_sent_at
      nil
    end
  end

  test "email change verify_token fails when pending_email is blank" do
    user = users(:one)
    user.update!(
      pending_email: nil,
      email_change_token: SecureRandom.hex(16),
      email_change_sent_at: Time.current
    )

    assert_equal false, EmailChangeService.verify_token(user.email_change_token)
  end

  test "email change generate_and_send returns false when persistence fails" do
    user = UpdateFailingUser.new(id: users(:one).id)
    result = EmailChangeService.generate_and_send(user, "new-email@example.com")

    assert_equal false, result
  end

  test "email verification send returns false when token persistence fails" do
    user = UpdateFailingUser.new
    service = EmailVerificationService.new(user)
    result = service.send_verification_email("www.rubusoo.com", :https)

    assert_equal false, result
  end
end
