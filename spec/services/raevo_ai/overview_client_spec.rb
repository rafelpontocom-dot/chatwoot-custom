require 'rails_helper'

RSpec.describe RaevoAi::OverviewClient do
  let(:integration) do
    RaevoAiIntegration.create!(
      account: create(:account),
      clinic_id: 'clinic-anna-alice',
      enabled: true
    )
  end

  describe '#fetch' do
    it 'uses the server-side clinic mapping and returns only the public contract' do
      response = instance_double(
        HTTParty::Response,
        success?: true,
        body: {
          status: 'active',
          clinic_name: 'Dra. Anna Alice',
          package: 'complete',
          active_prompt_version: 12,
          knowledge_count: 8,
          open_reviews: 2,
          usage_30d: { conversations: 44, handoffs: 5, appointments: 9, payments: 3, internal_cost: 99 },
          clinic_id: 'must-not-leak',
          service_token: 'must-not-leak'
        }.to_json
      )

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        expect(HTTParty).to receive(:get).with(
          'https://elis.internal/internal/chatwoot/overview',
          headers: {
            'Accept' => 'application/json',
            'Authorization' => 'Bearer server-secret',
            'X-Raevo-Clinic-Id' => 'clinic-anna-alice'
          },
          timeout: 10
        ).and_return(response)

        expect(described_class.new(integration: integration).fetch).to eq(
          'status' => 'active',
          'clinic_name' => 'Dra. Anna Alice',
          'package' => 'complete',
          'active_prompt_version' => 12,
          'knowledge_count' => 8,
          'open_reviews' => 2,
          'usage_30d' => {
            'conversations' => 44,
            'handoffs' => 5,
            'appointments' => 9,
            'payments' => 3
          }
        )
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

    it 'rejects a successful response outside the public object contract' do
      response = instance_double(HTTParty::Response, success?: true, body: ['unexpected'].to_json)

      with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'server-secret' do
        allow(HTTParty).to receive(:get).and_return(response)

        expect { described_class.new(integration: integration).fetch }
          .to raise_error(RaevoAi::UpstreamError, 'Raevo AI service unavailable')
      end
    end
  end
end
