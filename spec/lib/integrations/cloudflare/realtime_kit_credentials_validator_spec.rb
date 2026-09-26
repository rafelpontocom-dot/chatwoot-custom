require 'rails_helper'

RSpec.describe Integrations::Cloudflare::RealtimeKitCredentialsValidator do
  let(:account_id) { 'account_id' }
  let(:app_id) { 'app_id' }
  let(:api_token) { 'api_token' }
  let(:token_verify_url) { 'https://api.cloudflare.com/client/v4/user/tokens/verify' }
  let(:apps_url) { "https://api.cloudflare.com/client/v4/accounts/#{account_id}/realtime/kit/apps" }
  # `described_class` fica preso à classe que existia quando este ficheiro foi
  # lido, e em teste o Rails recarrega código (`cache_classes = false`): a
  # constante do mesmo nome passa a ser outro objeto. O `stub_const` resolve
  # pelo NOME, logo estufa a fresca — e tanto a chamada como o tamanho de
  # página têm de sair dessa, senão o stub do WebMock fica registado com um
  # `per_page` e o código pede outro.
  let(:validador) { Object.const_get(described_class.name) }
  let(:apps_page_size) { validador::APPS_PAGE_SIZE }

  it 'accepts an active token with access to the requested RealtimeKit app' do
    stub_token_verify(status: 'active')
    stub_apps_list([{ id: app_id }])

    expect(described_class.valid?(account_id, app_id, api_token)).to be true
    expect(described_class.validate(account_id, app_id, api_token).success?).to be true
  end

  it 'rejects inactive tokens' do
    stub_token_verify(status: 'disabled')

    expect(described_class.valid?(account_id, app_id, api_token)).to be false
    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:invalid_api_token)
  end

  it 'rejects tokens without access to the Cloudflare account' do
    stub_token_verify(status: 'active')
    stub_apps_request.to_return(status: 403, body: { success: false }.to_json)

    expect(described_class.valid?(account_id, app_id, api_token)).to be false
    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:invalid_account_or_permissions)
  end

  it 'rejects a RealtimeKit App ID that is not present in the account' do
    stub_token_verify(status: 'active')
    stub_apps_list([{ id: 'another_app_id' }])

    expect(described_class.valid?(account_id, app_id, api_token)).to be false
    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:app_not_found)
  end

  it 'accepts a RealtimeKit App ID from a later apps page' do
    stub_const("#{validador}::APPS_PAGE_SIZE", 1)
    stub_token_verify(status: 'active')
    stub_apps_list([{ id: 'another_app_id' }], page_no: 1, total_count: 2)
    stub_apps_list([{ id: app_id }], page_no: 2, total_count: 2)

    expect(validador.validate(account_id, app_id, api_token).success?).to be true
  end

  it 'rejects blank credentials without making a network call' do
    expect(described_class.valid?(nil, app_id, api_token)).to be false
    expect(described_class.valid?(account_id, nil, api_token)).to be false
    expect(described_class.valid?(account_id, app_id, nil)).to be false
    expect(described_class.validate(nil, app_id, api_token).error).to eq(:missing_credentials)
  end

  it 'rejects transient Cloudflare failures instead of saving unverified credentials' do
    stub_request(:get, token_verify_url).to_return(status: 500)
    stub_apps_list([{ id: app_id }])
    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:verification_failed)

    stub_token_verify(status: 'active')
    stub_apps_request.to_return(status: 500)
    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:verification_failed)
  end

  it 'rejects credentials when Cloudflare cannot be reached' do
    stub_request(:get, token_verify_url).to_raise(Faraday::TimeoutError)

    expect(described_class.validate(account_id, app_id, api_token).error).to eq(:verification_failed)
  end

  def stub_token_verify(status:)
    stub_request(:get, token_verify_url)
      .with(headers: { 'Authorization' => "Bearer #{api_token}" })
      .to_return(status: 200, body: { success: true, result: { status: status } }.to_json)
  end

  def stub_apps_list(apps, page_no: 1, total_count: apps.size)
    stub_apps_request(page_no: page_no)
      .to_return(status: 200, body: apps_response_body(apps, total_count: total_count).to_json)
  end

  def stub_apps_request(page_no: 1)
    stub_request(:get, apps_url)
      .with(
        headers: { 'Authorization' => "Bearer #{api_token}" },
        query: { page_no: page_no.to_s, per_page: apps_page_size.to_s }
      )
  end

  def apps_response_body(apps, total_count: apps.size)
    { success: true, data: apps.map(&:stringify_keys), paging: { total_count: total_count } }
  end
end
