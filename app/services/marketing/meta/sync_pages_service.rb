class Marketing::Meta::SyncPagesService
  # As paginas que o anunciante administra, e o token de cada uma.
  #
  # O token de pagina vai para a coluna cifrada `page_tokens`, nao para o
  # `settings`, que sai inteiro no serializador.
  def initialize(connection:)
    @connection = connection
  end

  def perform
    pages = fetch_pages
    connection.update!(
      settings: connection.settings.merge('pages' => pages.map { |page| page.except('access_token') }),
      page_tokens: connection.stored_page_tokens.merge(page_tokens(pages)).to_json,
      last_verified_at: Time.current,
      status: 'connected',
      last_error: nil
    )
    pages
  rescue Marketing::Meta::ApiError => e
    connection.mark_attention!(e)
    raise
  end

  private

  attr_reader :connection

  def fetch_pages
    response = Marketing::Meta::GraphClient.request(
      :get, '/me/accounts',
      fields: 'id,name,access_token,tasks', access_token: connection.access_token, limit: 100
    )
    Array(response['data'])
  end

  # Mesclado, nao substituido: uma pagina que sumiu do /me/accounts por perda
  # temporaria de acesso nao deve levar junto o token que ainda funciona.
  def page_tokens(pages)
    pages.filter_map { |page| [page['id'].to_s, page['access_token']] if page['access_token'].present? }.to_h
  end
end
