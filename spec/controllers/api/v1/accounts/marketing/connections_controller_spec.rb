require 'rails_helper'

RSpec.describe 'Marketing connections API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_path) { "/api/v1/accounts/#{account.id}/marketing/connections" }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', display_name: 'Clinica',
      status: 'connected', access_token: 'tok', expires_at: 30.days.from_now
    )
  end

  before { MarketingModuleSetting.create!(account: account, enabled: true) }

  it 'refuses when the module is off' do
    account.marketing_module_setting.update!(enabled: false)

    get base_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'never sends the access token to the browser' do
    connection

    get base_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body['payload'].first
    expect(body).to include('provider' => 'meta', 'status' => 'connected')
    expect(body.keys).not_to include('access_token')
  end

  it 'warns while there is still time to reconnect' do
    connection.update!(expires_at: 3.days.from_now)

    get base_path, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].first['token_expiring']).to be(true)
  end

  it 'only lets someone who can configure start a connection' do
    post "#{base_path}/authorization_url", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'says so plainly when the Lead Ads app was never configured' do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_APP_ID', nil).and_return(nil)

    post "#{base_path}/authorization_url", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to match(/not configured/)
  end

  # Desconectar para de receber; o que ja entrou continua explicando de onde veio.
  it 'clears the credentials when disconnected' do
    delete "#{base_path}/#{connection.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(connection.reload).to have_attributes(status: 'disconnected', access_token: nil)
  end

  it 'turns a Meta failure into a 422 without leaking the provider text' do
    allow(Marketing::Meta::SyncPagesService).to receive(:new)
      .and_raise(Marketing::Meta::ApiError, 'Meta responded 400: OAuthException (190)')

    post "#{base_path}/#{connection.id}/sync_pages", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Sem o motivo a tela so consegue dizer "o Meta recusou", que nao ajuda
  # ninguem a descobrir que falta controle total da pagina.
  it 'says why Meta refused so the screen can point at the fix' do
    allow(Marketing::Meta::SubscribePageService).to receive(:new)
      .and_raise(Marketing::Meta::ApiError.new('Meta responded 403: OAuthException (200)', code: 200))

    post "#{base_path}/#{connection.id}/subscribe_page", params: { page_id: '1' },
                                                         headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error_code']).to eq('permission')
  end

  it 'refuses a connection from another account' do
    stranger = create(:account)
    other = stranger.marketing_provider_connections.create!(provider: 'meta', external_account_id: 'x')

    delete "#{base_path}/#{other.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'reports which permissions Meta withheld' do
    allow(Marketing::Meta::PermissionAuditService).to receive(:new).and_return(
      instance_double(Marketing::Meta::PermissionAuditService,
                      perform: { granted: ['pages_show_list'], missing: ['leads_retrieval'] })
    )

    get "#{base_path}/#{connection.id}/permissions", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['missing']).to eq(['leads_retrieval'])
  end

  it 'keeps the permission audit away from someone who only reads the funnel' do
    get "#{base_path}/#{connection.id}/permissions", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  # O /me/accounts do Meta devolve todas as páginas que a pessoa administra.
  # Numa agência, isso inclui as dos outros clientes.
  it 'keeps the page list away from someone who only reads the funnel' do
    connection

    get base_path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
