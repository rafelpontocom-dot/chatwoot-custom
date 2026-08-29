class Forms::TurnstileVerificationService
  VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'.freeze

  def initialize(token:, remote_ip:)
    @token = token
    @remote_ip = remote_ip
  end

  def valid?
    return false if token.blank? || secret_key.blank?

    response.parsed_response['success'] == true
  rescue StandardError => e
    Rails.logger.warn("[forms_turnstile] verification failed: #{e.class}")
    false
  end

  private

  attr_reader :token, :remote_ip

  def secret_key
    ENV.fetch('RAEVO_TURNSTILE_SECRET_KEY', nil)
  end

  def response
    HTTParty.post(
      VERIFY_URL,
      body: { secret: secret_key, response: token, remoteip: remote_ip },
      timeout: 5
    )
  end
end
