require 'rails_helper'

RSpec.describe Marketing::Meta::PageTokenService do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'user-token'
    )
  end

  # O motivo de guardar: token de pagina vindo de um token de usuario de longa
  # duracao nao expira. Com ele no banco, o lead continua entrando depois dos
  # 60 dias, sem ninguem reconectar.
  it 'serves a stored token without asking Meta anything' do
    connection.store_page_tokens!('10' => 'page-token')

    expect(described_class.new(connection: connection, page_id: '10').token).to eq('page-token')
    expect(a_request(:get, /graph\.facebook\.com/)).not_to have_been_made
  end

  it 'fetches the page list when the page is one we never saw' do
    stub_request(:get, %r{graph\.facebook\.com/.*/me/accounts}).to_return(
      status: 200, body: { data: [{ 'id' => '10', 'name' => 'Clinica', 'access_token' => 'fresh' }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect(described_class.new(connection: connection, page_id: '10').token).to eq('fresh')
  end

  it 'says so plainly when Meta does not hand over a token for that page' do
    stub_request(:get, %r{graph\.facebook\.com/.*/me/accounts}).to_return(
      status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' }
    )

    expect { described_class.new(connection: connection, page_id: '10').token }
      .to raise_error(Marketing::Meta::ApiError, 'Page token unavailable')
  end
end
