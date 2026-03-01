class TurnstileVerificationService
  TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  TIMEOUT = 5

  def initialize(token, remote_ip)
    @token = token
    @remote_ip = remote_ip
  end

  def verify
    return false if @token.blank?

    response = verify_with_cloudflare
    response && response["success"] == true
  rescue StandardError => e
    Rails.logger.error("[TurnstileVerificationService] #{e.class}: #{e.message}")
    false
  end

  private

  def verify_with_cloudflare
    uri = URI(TURNSTILE_VERIFY_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/x-www-form-urlencoded")
    request.body = URI.encode_www_form({
      secret: secret_key,
      response: @token,
      remoteip: @remote_ip
    })

    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.warn("[TurnstileVerificationService] Request timeout: #{e.message}")
    nil
  end

  def secret_key
    ENV.fetch("TURNSTILE_SECRET_KEY", "")
  end
end
