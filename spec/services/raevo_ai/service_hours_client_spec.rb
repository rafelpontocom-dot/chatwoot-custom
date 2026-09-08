require 'rails_helper'

RSpec.describe RaevoAi::ServiceHoursClient do
  let(:integration) do
    RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-example', enabled: true)
  end
  let(:config) do
    {
      'enabled' => true,
      'timezone' => 'America/Sao_Paulo',
      'windows' => [{ 'days' => [1, 2, 3, 4, 5], 'start' => '08:00', 'end' => '18:00' }],
      'revision' => 2,
      'updated_at' => '2026-09-08T11:00:00.000Z',
      'source' => 'structured'
    }
  end

  it 'reads only the operational schedule through the service bridge' do
    response = instance_double(HTTParty::Response, success?: true, body: {
      'config' => config.merge('internal_notes' => 'must-not-leak')
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:get).with(
        'https://elis.internal/internal/chatwoot/service-hours',
        headers: hash_including('Authorization' => 'Bearer bridge-secret', 'X-Raevo-Clinic-Id' => 'clinic-example'),
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).fetch).to eq(response: config)
    end
  end

  it 'saves a revision-guarded operational schedule without exposing the service token to the browser' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: { 'config' => config }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:put).with(
        'https://elis.internal/internal/chatwoot/service-hours',
        headers: hash_including(
          'Authorization' => 'Bearer bridge-secret',
          'X-Raevo-Clinic-Id' => 'clinic-example',
          'X-Raevo-Actor-Ref' => 'chatwoot:3:6'
        ),
        body: {
          expected_revision: 1,
          config: config.slice('enabled', 'timezone', 'windows')
        }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).save(
               config: config.slice('enabled', 'timezone', 'windows'),
               expected_revision: 1,
               actor_ref: 'chatwoot:3:6'
             )).to eq(response: config)
    end
  end

  it 'preserves an optimistic revision conflict' do
    response = instance_double(HTTParty::Response, success?: false, code: 409, body: { 'error' => 'service_hours_config_conflict' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:put).and_return(response)
      expect do
        described_class.new(integration: integration).save(
          config: config.slice('enabled', 'timezone', 'windows'),
          expected_revision: 1,
          actor_ref: 'chatwoot:3:6'
        )
      end.to raise_error(RaevoAi::ServiceHoursClient::Conflict)
    end
  end
end
