require 'rails_helper'

RSpec.describe RaevoAi::PauseClient do
  let(:integration) do
    RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-example', enabled: true)
  end
  let(:endpoint) { 'https://elis.internal/internal/chatwoot/pause' }
  let(:active_state) { { 'paused' => false, 'paused_at' => nil, 'paused_by' => nil, 'revision' => 4 } }
  let(:paused_state) do
    { 'paused' => true, 'paused_at' => '2026-09-09T09:42:00.000Z', 'paused_by' => 'Ana', 'revision' => 5 }
  end

  def response_double(body)
    instance_double(HTTParty::Response, success?: true, code: 200, body: body.to_json)
  end

  it 'reads the operational state through the service bridge' do
    response = response_double('state' => active_state.merge('internal_token' => 'must-not-leak'))

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:get).with(
        endpoint,
        headers: hash_including('Authorization' => 'Bearer bridge-secret', 'X-Raevo-Clinic-Id' => 'clinic-example'),
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).fetch).to eq(response: active_state)
    end
  end

  it 'refuses a state that does not say whether the assistant is paused' do
    response = response_double('state' => { 'revision' => 4 })

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:get).and_return(response)

      expect { described_class.new(integration: integration).fetch }.to raise_error(RaevoAi::UpstreamError)
    end
  end

  it 'refuses an author name too long to fit the header' do
    response = response_double('state' => active_state.merge('paused_by' => 'a' * 200))

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:get).and_return(response)

      expect { described_class.new(integration: integration).fetch }.to raise_error(RaevoAi::UpstreamError)
    end
  end

  it 'pauses with the expected revision so a stale screen cannot overwrite a newer state' do
    response = response_double('state' => paused_state)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:put).with(
        endpoint,
        headers: hash_including('X-Raevo-Actor-Ref' => 'chatwoot:1:2', 'Content-Type' => 'application/json'),
        body: { expected_revision: 4, paused: true }.to_json,
        timeout: 10
      ).and_return(response)

      result = described_class.new(integration: integration).save(paused: true, expected_revision: 4, actor_ref: 'chatwoot:1:2')

      expect(result).to eq(response: paused_state)
    end
  end

  it 'raises a conflict when someone else changed the state first' do
    response = instance_double(HTTParty::Response, success?: false, code: 409, body: { 'error' => 'pause_state_conflict' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:put).and_return(response)

      expect { described_class.new(integration: integration).save(paused: true, expected_revision: 4, actor_ref: 'chatwoot:1:2') }
        .to raise_error(described_class::Conflict)
    end
  end

  it 'treats any other refusal as the service being unavailable' do
    response = instance_double(HTTParty::Response, success?: false, code: 500, body: { 'error' => 'boom' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:put).and_return(response)

      expect { described_class.new(integration: integration).save(paused: true, expected_revision: 4, actor_ref: 'chatwoot:1:2') }
        .to raise_error(RaevoAi::UpstreamError)
    end
  end

  it 'refuses to guess an endpoint when the bridge is not configured' do
    with_modified_env RAEVO_AI_SERVICE_URL: nil, RAEVO_AI_SERVICE_TOKEN: nil do
      expect { described_class.new(integration: integration).fetch }.to raise_error(RaevoAi::ConfigurationError)
    end
  end
end
