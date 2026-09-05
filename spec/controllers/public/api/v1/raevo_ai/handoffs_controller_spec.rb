require 'rails_helper'

RSpec.describe 'Raevo AI handoff commands API', type: :request do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:token) { 'a' * 64 }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'command_token_digest' => Digest::SHA256.hexdigest(token),
        'handoff' => {
          'team_id' => team.id,
          'allowed_inbox_ids' => [conversation.inbox_id],
          'labels' => ['intervencao-humana']
        }
      }
    )
  end
  let(:headers) do
    {
      'X-Raevo-Clinic-Id' => integration.clinic_id,
      'X-Raevo-Command-Token' => token
    }
  end
  let(:payload) do
    {
      action_id: 'act-handoff-001',
      conversation_id: conversation.display_id,
      reason: 'human_requested',
      note: 'O contato pediu uma pessoa da equipe.',
      account_id: create(:account).id
    }
  end

  describe 'POST /public/api/v1/raevo_ai/handoffs' do
    it 'authenticates the tenant and applies a handoff without trusting account_id from the body' do
      post '/public/api/v1/raevo_ai/handoffs', params: payload, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('action_id' => 'act-handoff-001', 'status' => 'applied')
      expect(conversation.reload.team_id).to eq(team.id)
    end

    it 'does not disclose or mutate data for an invalid tenant token' do
      expect do
        post '/public/api/v1/raevo_ai/handoffs', params: payload, headers: headers.merge('X-Raevo-Command-Token' => 'wrong'), as: :json
      end.not_to(change { conversation.reload.team_id })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'rate limits commands after authenticating the tenant' do
      limiter = instance_double(RaevoAi::CommandRateLimiter, allowed?: false)
      allow(RaevoAi::CommandRateLimiter).to receive(:new).with(integration: integration).and_return(limiter)

      post '/public/api/v1/raevo_ai/handoffs', params: payload, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body).to eq('error' => 'rate_limited')
    end
  end
end
