require 'rails_helper'

RSpec.describe 'Finance provider connections API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:connections_path) { "/api/v1/accounts/#{account.id}/finance/provider_connections" }

  it 'blocks provider setup until the finance module is enabled' do
    get connections_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'stores an Asaas key without serializing it back to the dashboard' do
    FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR')

    post connections_path,
         headers: administrator.create_new_auth_token,
         params: {
           provider_connection: {
             provider: 'asaas',
             environment: 'sandbox',
             api_key: 'asaas-sandbox-secret',
             display_name: 'Clínica RAEVO'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('provider' => 'asaas', 'status' => 'pending')
    expect(response.parsed_body).not_to have_key('api_key')
  end

  it 'lets an agent list safe connection details after the module is enabled' do
    FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR')
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'production',
      api_key: 'asaas-production-secret',
      status: 'connected'
    )

    get connections_path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(
      include('provider' => 'asaas', 'status' => 'connected')
    )
    expect(response.parsed_body.first).not_to have_key('api_key')
  end

  it 'activates a manual connection without accepting client-controlled provider status' do
    FinanceModuleSetting.create!(account: account, enabled: true, market: 'PT')

    post connections_path,
         headers: administrator.create_new_auth_token,
         params: {
           provider_connection: {
             provider: 'manual',
             environment: 'production',
             status: 'connected',
             display_name: 'Registo externo'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('provider' => 'manual', 'status' => 'connected')
    expect(FinanceProviderConnection.last.api_key).to be_nil
  end

  it 'verifies an Asaas credential on demand' do
    FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR')
    connection = FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-sandbox-secret',
      status: 'pending'
    )
    verified_connection = instance_double(FinanceProviderConnection, public_payload: { id: connection.id, status: 'connected' })
    service = instance_double(Finance::Asaas::VerifyConnectionService, perform: verified_connection)
    allow(Finance::Asaas::VerifyConnectionService).to receive(:new).with(connection: connection).and_return(service)

    post "#{connections_path}/#{connection.id}/verify", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'connected')
  end
end
