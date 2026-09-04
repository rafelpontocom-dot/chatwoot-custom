class Marketing::Meta::PermissionAuditService
  # Por que existe: com o token na mao, o Meta responde exatamente quais
  # permissoes concedeu. Sem isto, "OAuthException (200)" obriga a adivinhar
  # entre papel na pagina, permissao nao adicionada ao app e chave desmarcada
  # na tela de consentimento — tres causas com o mesmo sintoma.
  REQUIRED = Marketing::Meta::OauthService::SCOPE.split(',').freeze

  def initialize(connection:)
    @connection = connection
  end

  # `missing` e o que faltou: nem concedido nem sequer oferecido. E a lista que
  # a tela mostra, porque e ela que diz o que ir habilitar.
  def perform
    granted = granted_scopes
    { granted: granted, missing: REQUIRED - granted }
  end

  private

  attr_reader :connection

  def granted_scopes
    response = Marketing::Meta::GraphClient.request(
      :get, '/me/permissions', access_token: connection.access_token
    )
    Array(response['data']).select { |row| row['status'] == 'granted' }.filter_map { |row| row['permission'] }
  end
end
