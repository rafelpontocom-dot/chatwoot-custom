require 'rails_helper'

RSpec.describe Marketing::Meta::OauthService do
  let(:account) { create(:account) }

  before do
    # O ambiente de teste usa :null_store, e o `state` do OAuth vive no cache:
    # sem uma loja de verdade não há ida e volta para testar.
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_APP_ID', nil).and_return('app-1')
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_APP_SECRET', nil).and_return('secret-1')
    allow(GlobalConfigService).to receive(:load).with('MARKETING_META_OAUTH_CALLBACK_URL', anything)
                                                .and_return('https://raevo.test/marketing/meta/callback')
  end

  describe '#authorization_url' do
    it 'asks for the permissions lead retrieval actually needs' do
      url = described_class.new(account: account).authorization_url

      expect(url).to start_with('https://www.facebook.com/v21.0/dialog/oauth')
      expect(url).to include('leads_retrieval', 'pages_show_list', 'pages_manage_metadata')
    end

    # O Meta recusa ler /{pagina}/leadgen_forms sem esta, com "(#200) Requires
    # pages_manage_ads permission" — e nenhuma das outras a substitui.
    it 'asks for the permission that lists the lead forms' do
      expect(described_class.new(account: account).authorization_url).to include('pages_manage_ads')
    end

    it 'refuses when the Lead Ads app was never configured' do
      allow(GlobalConfigService).to receive(:load).with('MARKETING_META_APP_ID', nil).and_return(nil)

      expect { described_class.new(account: account).authorization_url }
        .to raise_error(Marketing::Meta::ApiError, /not configured/)
    end
  end

  describe '.connect!' do
    let(:state) do
      url = described_class.new(account: account).authorization_url
      CGI.parse(URI.parse(url).query)['state'].first
    end

    before do
      allow(Marketing::Meta::GraphClient).to receive(:request).with(:get, '/oauth/access_token', hash_including(:code))
                                                              .and_return('access_token' => 'short')
      allow(Marketing::Meta::GraphClient).to receive(:request)
        .with(:get, '/oauth/access_token', hash_including(grant_type: 'fb_exchange_token'))
        .and_return('access_token' => 'long', 'expires_in' => 5_184_000)
      allow(Marketing::Meta::GraphClient).to receive(:request).with(:get, '/me', anything)
                                                              .and_return('id' => 'meta-user-1', 'name' => 'Clinica')
      allow(Marketing::Meta::GraphClient).to receive(:request).with(:get, '/me/accounts', anything)
                                                              .and_return('data' => [])
    end

    # O Meta nao emite refresh token: o token curto tem de virar um de ~60 dias
    # ou a conexao morre em horas.
    it 'trades the short lived token for a long lived one' do
      connection = described_class.connect!(code: 'abc', state: state)

      expect(connection.access_token).to eq('long')
      expect(connection.status).to eq('connected')
      expect(connection.expires_at).to be_within(1.day).of(60.days.from_now)
    end

    it 'ties the connection to the account that started the flow' do
      expect(described_class.connect!(code: 'abc', state: state).account_id).to eq(account.id)
    end

    # Desconectar guarda a linha porque formulario e toque apontam para ela;
    # reconectar tem de reviver essa mesma linha, e nao esbarrar no indice.
    it 'revives the row left behind by a disconnect' do
      old = account.marketing_provider_connections.create!(
        provider: 'meta', external_account_id: 'meta-user-1', status: 'disconnected',
        access_token: nil, last_error: 'Meta responded 400: OAuthException (2500)'
      )

      connection = described_class.connect!(code: 'abc', state: state)

      expect(connection.id).to eq(old.id)
      expect(connection).to have_attributes(status: 'connected', access_token: 'long', last_error: nil)
      expect(account.marketing_provider_connections.count).to eq(1)
    end

    it 'refuses a state that was already used' do
      described_class.connect!(code: 'abc', state: state)

      expect { described_class.connect!(code: 'abc', state: state) }
        .to raise_error(Marketing::Meta::ApiError, /expired/)
    end

    it 'refuses a state nobody issued' do
      expect { described_class.connect!(code: 'abc', state: 'invented') }
        .to raise_error(Marketing::Meta::ApiError, /expired/)
    end
  end
end
