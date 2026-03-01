module TurnstileVerifiable
  private

  def turnstile_verification_result(token)
    return :skipped if ENV["SKIP_TURNSTILE_VERIFICATION"] == "true"
    return :missing if token.blank?

    service = TurnstileVerificationService.new(token, request.remote_ip)
    service.verify ? :ok : :failed
  end

  def verify_turnstile_for_json!(token:, missing_message:, failed_message:)
    case turnstile_verification_result(token)
    when :ok, :skipped
      true
    when :missing
      render json: { error: missing_message }, status: :unprocessable_entity
      false
    else
      render json: { error: failed_message }, status: :unprocessable_entity
      false
    end
  end

  def verify_turnstile_for_html!(token:, on_missing:, on_failed:)
    case turnstile_verification_result(token)
    when :ok, :skipped
      true
    when :missing
      on_missing.call
      false
    else
      on_failed.call
      false
    end
  end
end
