class Rack::Attack
  MAX_MULTIPART_BODY_BYTES = 20.megabytes

  # Allow any requests from health check endpoint
  safelist("allow health check") do |req|
    req.path == "/up" && req.request_method == "GET"
  end

  # Allow CSS/JS/images and static files
  safelist("allow static assets") do |req|
    req.path.start_with?("/packs/", "/assets/") ||
    req.path.match?(%r{\.(?:js|css|gif|jpg|jpeg|png|svg|woff|woff2|ttf|eot)$}i)
  end

  # Throttle registrations by IP (POST /users)
  # Devise routes: POST /users creates a new user (registrations#create)
  throttle("registrations by ip", limit: 5, period: 60) do |req|
    if req.path == "/users" && req.request_method == "POST"
      req.ip
    end
  end

  # Throttle login attempts by IP (POST /users/sign_in)
  # Devise routes: POST /users/sign_in authenticates user (sessions#create)
  throttle("logins by ip", limit: 10, period: 60) do |req|
    if req.path == "/users/sign_in" && req.request_method == "POST"
      req.ip
    end
  end

  # Throttle contact form submissions by IP (POST /contact_requests)
  throttle("contact by ip", limit: 5, period: 60) do |req|
    if req.path == "/contact_requests" && req.request_method == "POST"
      req.ip
    end
  end

  # Throttle email verification resend by IP (POST /email_verifications/resend)
  throttle("email verification resend by ip", limit: 10, period: 60) do |req|
    if req.path == "/email_verifications/resend" && req.request_method == "POST"
      req.ip
    end
  end

  # Throttle email change requests by IP (POST /email-change/request)
  throttle("email change request by ip", limit: 10, period: 60) do |req|
    if req.path == "/email-change/request" && req.request_method == "POST"
      req.ip
    end
  end

  # Throttle team invitation creates by IP.
  throttle("team invitations by ip", limit: 20, period: 60) do |req|
    if req.request_method == "POST" && req.path == "/team_invitations"
      req.ip
    end
  end

  # Throttle all other mutating requests by IP (100 per minute)
  # Catches POST, PUT, PATCH, DELETE on paths not matched above
  throttle("requests by ip", limit: 100, period: 60) do |req|
    if [ "POST", "PUT", "PATCH", "DELETE" ].include?(req.request_method)
      req.ip
    end
  end

  # Throttle multipart uploads by IP to reduce storage-abuse blast radius.
  throttle("multipart uploads by ip", limit: 20, period: 60) do |req|
    if [ "POST", "PUT", "PATCH" ].include?(req.request_method) && req.media_type == "multipart/form-data"
      req.ip
    end
  end

  # Drop oversized multipart requests early to reduce disk/bandwidth pressure.
  blocklist("oversized multipart body") do |req|
    [ "POST", "PUT", "PATCH" ].include?(req.request_method) &&
      req.media_type == "multipart/form-data" &&
      req.content_length.to_i > MAX_MULTIPART_BODY_BYTES
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda { |env|
    status  = 429
    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => "60"
    }
    body = {
      error: "Too many requests. Please try again later.",
      status: 429
    }.to_json
    [ status, headers, [ body ] ]
  }

  self.blocklisted_responder = lambda { |_env|
    status  = 413
    headers = {
      "Content-Type" => "application/json"
    }
    body = {
      error: "Payload too large.",
      status: 413
    }.to_json
    [ status, headers, [ body ] ]
  }
end

# Enable Rack::Attack - defaults to production only
# Set ENABLE_RACK_ATTACK=true in dev/test to test locally
if Rails.env.production? || ENV["ENABLE_RACK_ATTACK"] == "true"
  Rails.application.config.middleware.use Rack::Attack
end
