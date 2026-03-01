class EmailChangeService
  TOKEN_VALIDITY_SECONDS = 15 * 60  # 15 minutes

  def initialize(token)
    @token = token
  end

  def self.verify_token(token)
    service = new(token)
    service.verify
  end

  def verify
    user = User.find_by(email_change_token: @token)

    return false if user.blank?

    if user.email_change_sent_at.blank?
      return false
    end

    if Time.current > user.email_change_sent_at + TOKEN_VALIDITY_SECONDS.seconds
      # Token expired, clear it
      user.update(
        email_change_token: nil,
        email_change_sent_at: nil,
        pending_email: nil
      )
      return false
    end

    # Mark email as changed and clear token
    return false if user.pending_email.blank?

    updated = user.update(
      email: user.pending_email,
      email_verified_at: Time.current,
      email_change_token: nil,
      email_change_sent_at: nil,
      pending_email: nil
    )

    updated
  end

  def self.generate_and_send(user, new_email, host: nil, protocol: nil)
    return false if user.blank? || new_email.blank?

    # Check if email is already in use
    if User.where(email: new_email).where.not(id: user.id).exists?
      return false
    end

    token = SecureRandom.hex(32)
    updated = user.update(
      pending_email: new_email,
      email_change_token: token,
      email_change_sent_at: Time.current
    )
    return false unless updated

    send_email(user, new_email, token, host: host, protocol: protocol)
    true
  end

  private

  def self.send_email(user, new_email, token, host: nil, protocol: nil)
    EmailChangeMailer.with(
      user: user,
      new_email: new_email,
      token: token,
      host: host,
      protocol: protocol
    ).confirmation_email.deliver_later
  end
end
