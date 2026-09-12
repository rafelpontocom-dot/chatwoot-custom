require 'rails_helper'

RSpec.describe 'Raevo AI assistant name API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/assistant_name" }
  let!(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true) }

  it 'saves the name and answers with what she will now say' do
    client = instance_double(
      RaevoAi::AssistantNameClient,
      save: { response: { 'assistant_name' => 'Sofia', 'effective_name' => 'Sofia' } }
    )
    allow(RaevoAi::AssistantNameClient).to receive(:new).with(integration: integration).and_return(client)

    put path, params: { assistant_name: 'Sofia' }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['state']).to eq('assistant_name' => 'Sofia', 'effective_name' => 'Sofia')
  end

  it 'treats an empty name as going back to the default, not as a missing param' do
    client = instance_double(RaevoAi::AssistantNameClient,
                             save: { response: { 'assistant_name' => nil, 'effective_name' => 'Elis' } })
    allow(RaevoAi::AssistantNameClient).to receive(:new).and_return(client)

    put path, params: { assistant_name: '' }, headers: administrator.create_new_auth_token, as: :json

    expect(client).to have_received(:save).with(hash_including(assistant_name: nil))
    expect(response.parsed_body['state']['effective_name']).to eq('Elis')
  end

  it 'does not let an agent rename the assistant for the whole clinic' do
    put path, params: { assistant_name: 'Sofia' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'reports a conflict instead of overwriting someone else' do
    client = instance_double(RaevoAi::AssistantNameClient)
    allow(RaevoAi::AssistantNameClient).to receive(:new).and_return(client)
    allow(client).to receive(:save).and_raise(RaevoAi::AssistantNameClient::Conflict)

    put path, params: { assistant_name: 'Sofia' }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['error']).to eq('assistant_name_conflict')
  end

  it 'says the service is unavailable without leaking why' do
    client = instance_double(RaevoAi::AssistantNameClient)
    allow(RaevoAi::AssistantNameClient).to receive(:new).and_return(client)
    allow(client).to receive(:save).and_raise(RaevoAi::UpstreamError, 'upstream detail must not render')

    put path, params: { assistant_name: 'Sofia' }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).not_to include('upstream detail')
  end
end
