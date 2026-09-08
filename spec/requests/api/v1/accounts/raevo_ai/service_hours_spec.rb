require 'rails_helper'

RSpec.describe 'Raevo AI service hours API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/service_hours" }
  let(:config) do
    {
      enabled: true,
      timezone: 'America/Sao_Paulo',
      windows: [{ days: [1, 2, 3, 4, 5], start: '08:00', end: '18:00' }]
    }
  end

  it 'loads only the service hours bound to the account integration' do
    payload = config.deep_stringify_keys.merge('revision' => 2, 'updated_at' => nil, 'source' => 'structured')
    client = instance_double(RaevoAi::ServiceHoursClient, fetch: { response: payload })
    expect(RaevoAi::ServiceHoursClient).to receive(:new).with(integration: integration).and_return(client)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('config' => payload)
  end

  it 'saves a validated schedule with optimistic revision and actor reference' do
    payload = config.deep_stringify_keys.merge('revision' => 3, 'updated_at' => nil, 'source' => 'structured')
    client = instance_double(RaevoAi::ServiceHoursClient)
    expect(RaevoAi::ServiceHoursClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:save).with(
      config: config.deep_stringify_keys,
      expected_revision: 2,
      actor_ref: "chatwoot:#{account.id}:#{administrator.id}"
    ).and_return(response: payload)

    put path, params: { expected_revision: 2, config: config }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('config' => payload)
  end

  it 'rejects an invalid time range before calling the service' do
    integration
    expect(RaevoAi::ServiceHoursClient).not_to receive(:new)

    put path, params: {
      expected_revision: nil,
      config: config.merge(windows: [{ days: [1], start: '18:00', end: '08:00' }])
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'invalid_service_hours_config')
  end

  it 'rejects overlapping periods for the same weekday' do
    integration
    expect(RaevoAi::ServiceHoursClient).not_to receive(:new)

    put path, params: {
      expected_revision: nil,
      config: config.merge(windows: [
                             { days: [1], start: '08:00', end: '12:00' },
                             { days: [1], start: '11:30', end: '18:00' }
                           ])
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'invalid_service_hours_config')
  end

  it 'does not allow an agent to change the account schedule' do
    integration
    agent = create(:user, account: account, role: :agent)

    put path, params: { expected_revision: nil, config: config }, headers: agent.create_new_auth_token, as: :json

    expect(response).not_to have_http_status(:success)
  end

  it 'returns conflict when a newer revision was saved first' do
    client = instance_double(RaevoAi::ServiceHoursClient)
    allow(RaevoAi::ServiceHoursClient).to receive(:new).with(integration: integration).and_return(client)
    allow(client).to receive(:save).and_raise(RaevoAi::ServiceHoursClient::Conflict)

    put path, params: { expected_revision: 2, config: config }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to eq('error' => 'service_hours_config_conflict')
  end
end
