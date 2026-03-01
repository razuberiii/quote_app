class EmailVerificationService
  TOKEN_VALIDITY_SECONDS = 15 * 60 # 15 minutes

  def self.verify_token(token)
    return false if token.blank?

    user = User.find_by(email_verification_token: token)
    return false if user.blank?

    # Check if token is still valid
    if user.email_verification_token_sent_at.blank?
      return false
    end

    if Time.current > user.email_verification_token_sent_at + TOKEN_VALIDITY_SECONDS.seconds
      return false
    end

    # Mark email as verified and clear token
    user.update(
      email_verified_at: Time.current,
      email_verification_token: nil,
      email_verification_token_sent_at: nil
    )

    true
  end

  def initialize(user)
    @user = user
  end

  def send_verification_email(verification_url)
    return false if @user.blank?

    generate_token
    send_email(verification_url)

    true
  end

  private

  def generate_token
    token = SecureRandom.hex(32)
    @user.update(
      email_verification_token: token,
      email_verification_token_sent_at: Time.current
    )
    token
  end

  def send_email(verification_url)
    EmailVerificationMailer.with(
      user: @user,
      verification_link: verification_url
    ).verification_email.deliver_later
  end
end
