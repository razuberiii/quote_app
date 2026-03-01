class EmailVerificationService
  TOKEN_VALIDITY_SECONDS = 15 * 60  # 15 minutes
  RESEND_COOLDOWN_SECONDS = 60     # 1 minute between resends

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

  def self.can_resend?(user)
    return true if user.email_verification_token_sent_at.blank?

    # Check if cooldown period has passed
    Time.current >= user.email_verification_token_sent_at + RESEND_COOLDOWN_SECONDS.seconds
  end

  def self.seconds_until_resend_allowed(user)
    return 0 if can_resend?(user)
    return 0 if user.email_verification_token_sent_at.blank?

    seconds_elapsed = (Time.current - user.email_verification_token_sent_at).to_i
    [ RESEND_COOLDOWN_SECONDS - seconds_elapsed, 0 ].max
  end

  def initialize(user)
    @user = user
  end

  def send_verification_email(host = nil, protocol = :https)
    return false if @user.blank?

    # Check if user can resend (not in cooldown)
    unless self.class.can_resend?(@user)
      return false
    end

    token = generate_token
    verification_url = Rails.application.routes.url_helpers.email_verification_url(
      token: token,
      host: host || Rails.application.config.action_mailer.default_url_options[:host],
      protocol: protocol
    )

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
