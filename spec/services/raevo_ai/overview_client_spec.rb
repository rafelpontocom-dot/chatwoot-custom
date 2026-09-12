require 'rails_helper'

RSpec.describe RaevoAi::OverviewClient do
  let(:integration) do
    RaevoAiIntegration.create!(
      account: create(:account),
      clinic_id: 'clinic-anna-alice',
      enabled: true
    )
  end
  let(:assistant_profile) do
    {
      identity: 'Secretária virtual da clínica.',
      personality: 'Serena e objetiva.',
      voice_style: 'Frases curtas e linguagem simples.',
      tool_policy: 'must-not-leak'
    }
  end
  let(:sanitized_assistant_profile) { assistant_profile.except(:tool_policy).stringify_keys }
  let(:upstream_payload) do
    {
      status: 'active',
      clinic_name: 'Dra. Anna Alice',
      package: 'complete',
      capabilities: {
        package: 'agenda',
        capabilities: [
          { id: 'atendimento', provider: nil, internal_id: 'must-not-leak' },
          { id: 'crm', provider: 'chatwoot', command_token: 'must-not-leak' },
          { id: 'agenda', provider: 'feegow', provider_config: { api_key: 'must-not-leak' } }
        ]
      },
      active_prompt_version: 12,
      knowledge_count: 8,
      open_reviews: 2,
      operational_quality: {
        post_delivery_actions_pending: 1,
        post_delivery_actions_applied: 4,
        post_delivery_actions_failed: 2,
        manual_reconciliations: 3,
        attention_level: 'action_required',
        attention_reasons: %w[post_delivery_actions_failed post_delivery_actions_pending manual_reconciliations],
        reconciliation_reason: 'must-not-leak'
      },
      assistant_profile: assistant_profile,
      usage: {
        conversations: 44,
        handoffs: 5,
        appointments: 9,
        payments: 3,
        model_calls: 83,
        prompt_tokens: 1200,
        completion_tokens: 600,
        provider_reported_cost_usd: 1.25,
        catalog_estimated_cost_usd: 0.75,
        cost_unavailable_calls: 2,
        internal_cost: 99
      },
      clinic_id: 'must-not-leak',
      service_token: 'must-not-leak'
    }
  end
  let(:public_payload) do
    upstream_payload.except(:clinic_id, :service_token).merge(
      capabilities: {
        'package' => 'agenda',
        'capabilities' => [
          { 'id' => 'atendimento', 'provider' => nil },
          { 'id' => 'crm', 'provider' => 'chatwoot' },
          { 'id' => 'agenda', 'provider' => 'feegow' }
        ]
      },
      assistant_profile: sanitized_assistant_profile,
      operational_quality: {
        'post_delivery_actions_pending' => 1,
        'post_delivery_actions_applied' => 4,
        'post_delivery_actions_failed' => 2,
        'manual_reconciliations' => 3,
        'attention_level' => 'action_required',
        'attention_reasons' => %w[post_delivery_actions_failed post_delivery_actions_pending manual_reconciliations]
      },
      usage: upstream_payload[:usage].except(:internal_cost).stringify_keys
    ).stringify_keys
  end

  describe '#fetch' do
    it 'uses the server-side clinic mapping and returns only the public contract' do
      response = instance_double(
        HTTParty::Response,
        success?: true,
        body: upstream_payload.to_json
      )

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        expect(HTTParty).to receive(:get).with(
          'https://elis.internal/internal/chatwoot/overview?days=30',
          headers: {
            'Accept' => 'application/json',
            'Authorization' => 'Bearer server-secret',
            'X-Raevo-Clinic-Id' => 'clinic-anna-alice'
          },
          timeout: 10
        ).and_return(response)

        expect(described_class.new(integration: integration).fetch).to eq(public_payload)
      end
    end

    it 'rejects missing server-side configuration before making a request' do
      with_modified_env RAEVO_AI_SERVICE_URL: nil, RAEVO_AI_SERVICE_TOKEN: nil do
        expect(HTTParty).not_to receive(:get)

        expect { described_class.new(integration: integration).fetch }
          .to raise_error(RaevoAi::ConfigurationError)
      end
    end

    it 'normalizes upstream failures without exposing their response' do
      response = instance_double(HTTParty::Response, success?: false, code: 500)

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        allow(HTTParty).to receive(:get).and_return(response)

        expect { described_class.new(integration: integration).fetch }
          .to raise_error(RaevoAi::UpstreamError, 'Raevo AI service unavailable')
      end
    end

    it 'lets the commercial journey and the freshness stamps through' do
      payload = {
        'status' => 'active',
        'generated_at' => '2026-09-09T22:00:00.000Z',
        'last_delivered_at' => '2026-09-09T21:56:00.000Z',
        'usage' => { 'conversations' => 308, 'pre_scheduled' => 27, 'appointments' => 18 }
      }
      response = instance_double(HTTParty::Response, success?: true, body: payload.to_json)

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        allow(HTTParty).to receive(:get).and_return(response)

        result = described_class.new(integration: integration).fetch

        expect(result['generated_at']).to eq('2026-09-09T22:00:00.000Z')
        expect(result['last_delivered_at']).to eq('2026-09-09T21:56:00.000Z')
        expect(result['usage']['pre_scheduled']).to eq(27)
      end
    end

    it 'rejects a successful response outside the public object contract' do
      response = instance_double(HTTParty::Response, success?: true, body: ['unexpected'].to_json)

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        allow(HTTParty).to receive(:get).and_return(response)

        expect { described_class.new(integration: integration).fetch }
          .to raise_error(RaevoAi::UpstreamError, 'Raevo AI service unavailable')
      end
    end
  end

  it 'asks the bridge for the window the clinic chose' do
    response = instance_double(HTTParty::Response, success?: true, body: { 'status' => 'active' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
      expect(HTTParty).to receive(:get).with(
        'https://elis.internal/internal/chatwoot/overview?days=7', anything
      ).and_return(response)

      described_class.new(integration: integration).fetch(window_days: 7)
    end
  end

  it 'falls back to thirty days instead of forwarding a window nobody offers' do
    response = instance_double(HTTParty::Response, success?: true, body: { 'status' => 'active' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
      expect(HTTParty).to receive(:get).with(
        'https://elis.internal/internal/chatwoot/overview?days=30', anything
      ).and_return(response)

      described_class.new(integration: integration).fetch(window_days: 4000)
    end
  end

  it 'still reads a runtime that has not been renamed yet' do
    # Os dois serviços implantam separadamente. Um Chatwoot novo a falar com um
    # runtime antigo não pode deixar a clínica sem números.
    corpo = { 'status' => 'active', 'usage_30d' => { 'conversations' => 12 } }.to_json
    response = instance_double(HTTParty::Response, success?: true, body: corpo)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
      allow(HTTParty).to receive(:get).and_return(response)

      resultado = described_class.new(integration: integration).fetch

      expect(resultado['usage']).to eq('conversations' => 12)
    end
  end

  it 'prefers the new name when the runtime sends both during the rollout' do
    corpo = {
      'status' => 'active',
      'usage' => { 'conversations' => 7 },
      'usage_30d' => { 'conversations' => 12 }
    }.to_json
    response = instance_double(HTTParty::Response, success?: true, body: corpo)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
      allow(HTTParty).to receive(:get).and_return(response)

      resultado = described_class.new(integration: integration).fetch

      expect(resultado['usage']).to eq('conversations' => 7)
    end
  end
end
