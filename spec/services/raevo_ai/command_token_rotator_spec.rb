require 'rails_helper'

RSpec.describe RaevoAi::CommandTokenRotator do
  let(:integration) do
    RaevoAiIntegration.create!(
      account: create(:account),
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: { 'handoff' => { 'labels' => ['intervencao-humana'] } }
    )
  end

  it 'returns a token once and persists only its digest without replacing other settings' do
    token = described_class.new(integration: integration).rotate!

    stored_settings = integration.reload.settings
    expect(token.length).to be >= 64
    expect(stored_settings['command_token_digest']).to eq(Digest::SHA256.hexdigest(token))
    expect(stored_settings.values).not_to include(token)
    expect(stored_settings.dig('handoff', 'labels')).to eq(['intervencao-humana'])
  end

  it 'invalidates the prior token when rotated' do
    first_token = described_class.new(integration: integration).rotate!
    second_token = described_class.new(integration: integration).rotate!

    expect(RaevoAi::CommandAuthenticator.new(clinic_id: integration.clinic_id, token: first_token).authenticate).to be_nil
    expect(RaevoAi::CommandAuthenticator.new(clinic_id: integration.clinic_id, token: second_token).authenticate).to eq(integration)
  end
end
