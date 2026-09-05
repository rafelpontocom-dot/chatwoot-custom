require 'rails_helper'

RSpec.describe RaevoAi::CommandAuthenticator do
  describe '#authenticate' do
    it 'returns only the enabled integration whose tenant token matches' do
      token = 'a' * 64
      integration = RaevoAiIntegration.create!(
        account: create(:account),
        clinic_id: 'clinic-demo',
        enabled: true,
        settings: { 'command_token_digest' => Digest::SHA256.hexdigest(token) }
      )

      authenticated_integration = described_class.new(clinic_id: 'clinic-demo', token: token).authenticate

      expect(authenticated_integration).to eq(integration)
    end

    it 'does not authenticate a disabled integration or an invalid token' do
      token = 'a' * 64
      disabled_integration = RaevoAiIntegration.create!(
        account: create(:account),
        clinic_id: 'clinic-disabled',
        enabled: false,
        settings: { 'command_token_digest' => Digest::SHA256.hexdigest(token) }
      )
      enabled_integration = RaevoAiIntegration.create!(
        account: create(:account),
        clinic_id: 'clinic-enabled',
        enabled: true,
        settings: { 'command_token_digest' => Digest::SHA256.hexdigest(token) }
      )

      expect(described_class.new(clinic_id: disabled_integration.clinic_id, token: token).authenticate).to be_nil
      expect(described_class.new(clinic_id: enabled_integration.clinic_id, token: 'wrong-token').authenticate).to be_nil
    end
  end
end
