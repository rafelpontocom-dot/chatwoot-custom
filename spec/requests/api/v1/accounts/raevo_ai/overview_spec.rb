require 'rails_helper'

RSpec.describe 'Raevo AI overview API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/overview" }

  it 'returns a safe not configured state when the account has no integration' do
    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'connection_state' => 'not_configured',
      'operational_state' => nil,
      'overview' => nil
    )
  end

  it 'returns a safe disabled state without calling the ELIS service' do
    RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: false)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'connection_state' => 'disabled',
      'operational_state' => nil,
      'overview' => nil
    )
  end

  it 'returns the sanitized overview for the integration bound to the current account' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true)
    payload = { 'status' => 'active', 'clinic_name' => 'Dra. Anna Alice' }
    client = instance_double(RaevoAi::OverviewClient, fetch: payload)

    expect(RaevoAi::OverviewClient).to receive(:new).with(integration: integration).and_return(client)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'connection_state' => 'active',
      'operational_state' => 'healthy',
      # As duas etapas do funil que o Chatwoot responde sozinho entram ao lado
      # do que a ponte devolve.
      'overview' => payload.merge('opportunities_created' => 0, 'opportunities_qualified' => nil)
    )
  end

  it 'does not allow a user from another account to read the overview' do
    RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true)
    other_account = create(:account)
    outsider = create(:user, account: other_account, role: :administrator)

    get path, headers: outsider.create_new_auth_token, as: :json

    expect(response).not_to have_http_status(:success)
  end

  it 'reports missing service configuration without leaking details' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true)
    client = instance_double(RaevoAi::OverviewClient)
    allow(client).to receive(:fetch).and_raise(RaevoAi::ConfigurationError)
    allow(RaevoAi::OverviewClient).to receive(:new).with(integration: integration).and_return(client)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'connection_state' => 'unavailable',
      'operational_state' => 'unavailable',
      'overview' => nil
    )
  end

  it 'returns an unavailable state when the ELIS service cannot be reached' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true)
    client = instance_double(RaevoAi::OverviewClient)
    allow(client).to receive(:fetch).and_raise(RaevoAi::UpstreamError)
    allow(RaevoAi::OverviewClient).to receive(:new).with(integration: integration).and_return(client)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'connection_state' => 'unavailable',
      'operational_state' => 'unavailable',
      'overview' => nil
    )
  end
end
