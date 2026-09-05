class RaevoAi::CommandTokenRotator
  def initialize(integration:)
    @integration = integration
  end

  def rotate!
    token = SecureRandom.urlsafe_base64(48)
    @integration.update!(settings: @integration.settings.merge('command_token_digest' => Digest::SHA256.hexdigest(token)))
    token
  end
end
