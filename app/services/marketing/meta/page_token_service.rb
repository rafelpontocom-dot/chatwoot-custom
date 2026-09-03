class Marketing::Meta::PageTokenService
  # Toda chamada de pagina passa por aqui; ninguem le o token direto.
  # Se caiu do cache, busca de novo com o token do usuario.
  def initialize(connection:, page_id:)
    @connection = connection
    @page_id = page_id
  end

  def token
    cached = Marketing::Meta::SyncPagesService.page_token(connection, page_id)
    return cached if cached.present?

    Marketing::Meta::SyncPagesService.new(connection: connection).perform
    Marketing::Meta::SyncPagesService.page_token(connection, page_id).presence ||
      raise(Marketing::Meta::ApiError, 'Page token unavailable')
  end

  private

  attr_reader :connection, :page_id
end
