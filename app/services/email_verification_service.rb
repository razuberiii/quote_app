class EmailVerificationService
  CODE_VALIDITY_SECONDS = 15 * 60
  RESEND_COOLDOWN_SECONDS = 60
  CODE_LENGTH = 6
  MAX_ATTEMPTS = 5

  def self.can_resend?(user)
    return true if user.email_verification_code_sent_at.blank?

    Time.current >= user.email_verification_code_sent_at + RESEND_COOLDOWN_SECONDS.seconds
  end

  def self.seconds_until_resend_allowed(user)
    return 0 if can_resend?(user)
    return 0 if user.email_verification_code_sent_at.blank?

    seconds_elapsed = (Time.current - user.email_verification_code_sent_at).to_i
    [ RESEND_COOLDOWN_SECONDS - seconds_elapsed, 0 ].max
  end

  def initialize(user)
    @user = user
  end

  def send_verification_email(host = nil, protocol = :https)
    _host = host
    _protocol = protocol
    return false if @user.blank?

    return false unless self.class.can_resend?(@user)

    code = generate_code
    return false if code.blank?

    send_email(code)
    true
  end

  def verify_code(code)
    return :already_verified if @user.email_verified?
    return :too_many_attempts if @user.email_verification_attempts.to_i >= MAX_ATTEMPTS
    return :expired unless code_active?

    normalized_code = normalize_code(code)
    return register_failed_attempt unless normalized_code.match?(/\A\d{#{CODE_LENGTH}}\z/)

    if valid_code?(normalized_code)
      mark_verified
      :verified
    else
      register_failed_attempt
    end
  end

  private

  def generate_code
    code = format("%0#{CODE_LENGTH}d", SecureRandom.random_number(10**CODE_LENGTH))
    updated = @user.update(
      email_verification_code_digest: digest_for(code),
      email_verification_code_sent_at: Time.current,
      email_verification_attempts: 0
    )
    updated ? code : nil
  end

  def send_email(code)
    EmailVerificationMailer.with(
      user: @user,
      verification_code: code,
      validity_minutes: CODE_VALIDITY_SECONDS / 60
    ).verification_email.deliver_later
  end

  def code_active?
    return false if @user.email_verification_code_sent_at.blank?

    Time.current <= @user.email_verification_code_sent_at + CODE_VALIDITY_SECONDS.seconds
  end

  def valid_code?(code)
    expected_digest = @user.email_verification_code_digest.to_s
    return false if expected_digest.blank?

    provided_digest = digest_for(code)
    return false if provided_digest.length != expected_digest.length

    ActiveSupport::SecurityUtils.secure_compare(provided_digest, expected_digest)
  end

  def register_failed_attempt
    attempts = @user.email_verification_attempts.to_i + 1
    @user.update(email_verification_attempts: attempts)
    attempts >= MAX_ATTEMPTS ? :too_many_attempts : :invalid
  end

  def mark_verified
    @user.update(
      email_verified_at: Time.current,
      email_verification_code_digest: nil,
      email_verification_code_sent_at: nil,
      email_verification_attempts: 0
    )
  end

  def normalize_code(code)
    code.to_s.strip.gsub(/\s+/, "")
  end

  def digest_for(code)
    payload = "#{Rails.application.secret_key_base}--#{normalize_code(code)}"
    OpenSSL::Digest::SHA256.hexdigest(payload)
  end
end
