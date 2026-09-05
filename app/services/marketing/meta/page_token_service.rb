class Marketing::Meta::PageTokenService
  # Toda chamada de pagina passa por aqui; ninguem le o token direto.
  # Se ainda nao temos o da pagina, buscamos com o token do usuario.
  def initialize(connection:, page_id:)
    @connection = connection
    @page_id = page_id
  end

  def token
    stored = connection.page_token(page_id)
    return stored if stored.present?

    Marketing::Meta::SyncPagesService.new(connection: connection).perform
    connection.reload.page_token(page_id) ||
      raise(Marketing::Meta::ApiError, 'Page token unavailable')
  end

  private

  attr_reader :connection, :page_id
end
