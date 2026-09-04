require 'rails_helper'

RSpec.describe Marketing::Meta::SyncPagesService do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'user-token'
    )
  end
  let(:pages) do
    [{ 'id' => '10', 'name' => 'Clinica', 'access_token' => 'page-token', 'tasks' => %w[ADVERTISE MANAGE] }]
  end

  before do
    # O cache de teste e :null_store; o token de pagina so existe em cache.
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_request(:get, %r{graph\.facebook\.com/.*/me/accounts})
      .to_return(status: 200, body: { data: pages }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'keeps the page token out of the record and in the cache' do
    described_class.new(connection: connection).perform

    expect(connection.reload.settings['pages'].first).not_to have_key('access_token')
    expect(described_class.page_token(connection, '10')).to eq('page-token')
  end

  # Sem `tasks` a tela so descobre que falta permissao quando o clique falha.
  it 'records what the connected account may do on each page' do
    described_class.new(connection: connection).perform

    expect(connection.reload.settings['pages'].first['tasks']).to eq(%w[ADVERTISE MANAGE])
  end

  it 'flags the connection when Meta refuses, keeping the reason' do
    stub_request(:get, %r{graph\.facebook\.com/.*/me/accounts}).to_return(
      status: 403, body: { error: { type: 'OAuthException', code: 200 } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { described_class.new(connection: connection).perform }.to raise_error(Marketing::Meta::ApiError)
    expect(connection.reload).to have_attributes(status: 'attention', last_error: 'Meta responded 403: OAuthException (200)')
  end
end
