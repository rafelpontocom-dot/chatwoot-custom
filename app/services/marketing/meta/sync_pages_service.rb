class Marketing::Meta::SyncPagesService
  # As paginas que o anunciante administra, e o token de cada uma.
  #
  # O token de pagina fica no `settings` da conexao e nao numa coluna propria
  # porque sao varios; a coluna guarda o do usuario, que e o que os renova.
  def initialize(connection:)
    @connection = connection
  end

  def perform
    pages = fetch_pages
    connection.update!(
      settings: connection.settings.merge('pages' => pages.map { |page| page.except('access_token') }),
      last_verified_at: Time.current,
      status: 'connected',
      last_error: nil
    )
    store_page_tokens(pages)
    pages
  rescue Marketing::Meta::ApiError => e
    connection.mark_attention!(e)
    raise
  end

  # O token de pagina nunca sai por serializador nenhum.
  def self.page_token(connection, page_id)
    Rails.cache.read(cache_key(connection, page_id))
  end

  def self.cache_key(connection, page_id)
    "marketing_meta_page_token:#{connection.id}:#{page_id}"
  end

  private

  attr_reader :connection

  def fetch_pages
    response = Marketing::Meta::GraphClient.request(
      :get, '/me/accounts',
      fields: 'id,name,access_token', access_token: connection.access_token, limit: 100
    )
    Array(response['data'])
  end

  # Em cache e nao no banco: o token de pagina se recupera a qualquer momento
  # com o token do usuario, e o que nao e guardado nao vaza.
  def store_page_tokens(pages)
    pages.each do |page|
      next if page['access_token'].blank?

      Rails.cache.write(self.class.cache_key(connection, page['id']), page['access_token'], expires_in: 1.day)
    end
  end
end
