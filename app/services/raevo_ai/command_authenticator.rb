class RaevoAi::CommandAuthenticator
  def initialize(clinic_id:, token:)
    @clinic_id = clinic_id.to_s
    @token = token.to_s
  end

  def authenticate
    return if @clinic_id.blank? || @token.blank?

    integration = RaevoAiIntegration.find_by(clinic_id: @clinic_id, enabled: true)
    return unless integration

    expected_digest = integration.settings['command_token_digest'].to_s
    return if expected_digest.blank?

    token_digest = Digest::SHA256.hexdigest(@token)
    return unless ActiveSupport::SecurityUtils.secure_compare(expected_digest, token_digest)

    integration
  end
end
