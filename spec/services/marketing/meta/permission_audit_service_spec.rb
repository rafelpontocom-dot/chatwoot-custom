require 'rails_helper'

RSpec.describe Marketing::Meta::PermissionAuditService do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'user-token'
    )
  end

  def stub_permissions(rows)
    stub_request(:get, %r{graph\.facebook\.com/.*/me/permissions}).to_return(
      status: 200, body: { data: rows }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
  end

  # E este o caso real: a pessoa tem controle total da pagina e a chamada
  # continua sendo recusada porque a permissao nunca foi concedida.
  it 'names the permission that was never granted' do
    stub_permissions(
      [{ 'permission' => 'pages_show_list', 'status' => 'granted' },
       { 'permission' => 'leads_retrieval', 'status' => 'declined' }]
    )

    expect(described_class.new(connection: connection).perform[:missing])
      .to include('leads_retrieval', 'pages_manage_metadata')
  end

  it 'counts a declined permission as missing, not as granted' do
    stub_permissions([{ 'permission' => 'leads_retrieval', 'status' => 'declined' }])

    expect(described_class.new(connection: connection).perform[:granted]).to be_empty
  end

  it 'reports nothing missing once Meta granted the whole scope' do
    stub_permissions(described_class::REQUIRED.map { |scope| { 'permission' => scope, 'status' => 'granted' } })

    expect(described_class.new(connection: connection).perform)
      .to include(missing: [], granted: match_array(described_class::REQUIRED))
  end

  # A lista exigida e a que o OAuth pede; duas listas divergiriam em silencio.
  it 'audits exactly what the authorization asked for' do
    expect(described_class::REQUIRED).to eq(Marketing::Meta::OauthService::SCOPE.split(','))
  end
end
