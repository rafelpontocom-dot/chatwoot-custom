class Marketing::Meta::OauthService
  # Lead Ads precisa de um app Meta proprio.
  #
  # O `Facebook::Messenger::Server` montado em /bot ja e o callback do app do
  # FB_APP_ID, e um app Meta tem um callback por tipo de objeto — assinar
  # `leadgen` no app atual mandaria os leads para dentro da gem de Messenger.
  AUTHORIZE_URL = 'https://www.facebook.com/v21.0/dialog/oauth'.freeze
  TOKEN_URL = 'https://graph.facebook.com/v21.0/oauth/access_token'.freeze
  SCOPE = 'leads_retrieval,pages_show_list,pages_manage_metadata,pages_read_engagement,business_management'.freeze
  STATE_TTL = 10.minutes

  def initialize(account:)
    @account = account
  end

  def authorization_url
    ensure_credentials!
    state = SecureRandom.urlsafe_base64(32)
    # Chave em string: o que passa por um cache serializado nao volta
    # necessariamente com simbolos, e ler `[:account_id]` de volta daria nil.
    Rails.cache.write(self.class.state_cache_key(state), { 'account_id' => account.id }, expires_in: STATE_TTL)

    URI::HTTPS.build(
      host: 'www.facebook.com',
      path: '/v21.0/dialog/oauth',
      query: {
        client_id: app_id, redirect_uri: self.class.callback_url,
        scope: SCOPE, response_type: 'code', state: state
      }.to_query
    ).to_s
  end

  def self.connect!(code:, state:)
    new(account: account_from_state!(state)).connect!(code)
  end

  def connect!(code)
    short_lived = exchange_code(code)
    long_lived = exchange_for_long_lived(short_lived)
    profile = fetch_profile(long_lived[:access_token])

    connection = upsert_connection(profile, long_lived)
    Marketing::Meta::SyncPagesService.new(connection: connection).perform
    connection
  end

  # Estado de uso unico: um `state` reapresentado nao vale de novo.
  def self.account_from_state!(state)
    payload = Rails.cache.read(state_cache_key(state)).to_h.with_indifferent_access
    Rails.cache.delete(state_cache_key(state))
    raise Marketing::Meta::ApiError, 'Meta authorization expired' if payload[:account_id].blank?

    Account.find(payload[:account_id])
  end

  def self.state_cache_key(state)
    "marketing_meta_oauth:#{state}"
  end

  def self.callback_url
    GlobalConfigService.load(
      'MARKETING_META_OAUTH_CALLBACK_URL',
      "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/marketing/meta/callback"
    )
  end

  private

  attr_reader :account

  def app_id
    GlobalConfigService.load('MARKETING_META_APP_ID', nil)
  end

  def app_secret
    GlobalConfigService.load('MARKETING_META_APP_SECRET', nil)
  end

  def ensure_credentials!
    return if app_id.present? && app_secret.present?

    raise Marketing::Meta::ApiError, 'Meta Lead Ads app is not configured'
  end

  def exchange_code(code)
    ensure_credentials!
    Marketing::Meta::GraphClient.request(
      :get, '/oauth/access_token',
      client_id: app_id, client_secret: app_secret,
      redirect_uri: self.class.callback_url, code: code
    ).fetch('access_token')
  end

  # Sem refresh token no Meta: troca-se o token curto por um de ~60 dias.
  def exchange_for_long_lived(token)
    response = Marketing::Meta::GraphClient.request(
      :get, '/oauth/access_token',
      grant_type: 'fb_exchange_token', client_id: app_id,
      client_secret: app_secret, fb_exchange_token: token
    )
    {
      access_token: response.fetch('access_token'),
      expires_at: response['expires_in'].present? ? Time.current + response['expires_in'].to_i.seconds : 60.days.from_now
    }
  end

  def fetch_profile(token)
    Marketing::Meta::GraphClient.request(:get, '/me', fields: 'id,name', access_token: token)
  end

  def upsert_connection(profile, token)
    connection = account.marketing_provider_connections.find_or_initialize_by(
      provider: 'meta', external_account_id: profile.fetch('id')
    )
    connection.update!(
      display_name: profile['name'],
      access_token: token[:access_token],
      expires_at: token[:expires_at],
      status: 'connected',
      last_error: nil,
      last_verified_at: Time.current
    )
    connection
  end
end
