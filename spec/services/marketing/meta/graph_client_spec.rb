require 'rails_helper'

RSpec.describe Marketing::Meta::GraphClient do
  def stub_meta(status, body)
    stub_request(:get, %r{graph\.facebook\.com/.*/me/accounts}).to_return(
      status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'returns the parsed body when Meta accepts' do
    stub_meta(200, 'data' => [{ 'id' => '1' }])

    expect(described_class.request(:get, '/me/accounts')).to eq('data' => [{ 'id' => '1' }])
  end

  # O que a pessoa precisa saber e "va dar controle total da pagina", nao 200.
  it 'turns a permission refusal into a reason the screen can translate' do
    stub_meta(403, 'error' => { 'type' => 'OAuthException', 'code' => 200, 'message' => 'Requires pages_manage_metadata' })

    expect { described_class.request(:get, '/me/accounts') }
      .to raise_error(Marketing::Meta::ApiError) { |e| expect(e.reason).to eq('permission') }
  end

  it 'tells an expired session apart from a missing permission' do
    stub_meta(400, 'error' => { 'type' => 'OAuthException', 'code' => 190 })

    expect { described_class.request(:get, '/me/accounts') }
      .to raise_error(Marketing::Meta::ApiError) { |e| expect(e.reason).to eq('token_expired') }
  end

  # A mensagem do Meta cita nome e id de conta alheia; so tipo e codigo saem daqui.
  it 'never carries the provider text out of the client' do
    stub_meta(403, 'error' => { 'type' => 'OAuthException', 'code' => 200, 'message' => 'Page Clinica do Vizinho (99) denied' })

    expect { described_class.request(:get, '/me/accounts') }
      .to raise_error(Marketing::Meta::ApiError, 'Meta responded 403: OAuthException (200)')
  end

  it 'leaves an unknown code without a reason instead of guessing one' do
    stub_meta(500, 'error' => { 'type' => 'InternalError', 'code' => 1 })

    expect { described_class.request(:get, '/me/accounts') }
      .to raise_error(Marketing::Meta::ApiError) { |e| expect(e.reason).to be_nil }
  end
end
