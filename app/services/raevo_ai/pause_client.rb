# Pausa e retoma a Elis.
#
# O Chatwoot nao gera resposta nenhuma: quem fala com o paciente e o servico
# Raevo. Por isso pausar aqui e avisar la, e nao mexer numa coluna local. Em
# particular, `RaevoAiIntegration#enabled` NAO serve para isto: ela e a feature
# flag que faz o painel existir no menu, e desliga-la trancaria o cliente do
# lado de fora da propria tela onde fica o botao de retomar. Alem disso e o
# portao do CommandAuthenticator, o que deixaria a Elis a falar com o paciente
# sem conseguir gravar nada — o pior estado possivel.
#
# O contrato e o mesmo de service_hours: leitura simples, escrita otimista por
# revisao, e uma lista branca no regresso para o upstream nao poder injetar
# campos que a tela nao espera.
class RaevoAi::PauseClient
  class Conflict < StandardError; end

  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze
  PUBLIC_FIELDS = %w[paused paused_at paused_by revision].freeze
  MAX_ACTOR_LENGTH = 120

  def initialize(integration:)
    @integration = integration
  end

  def fetch
    validate_configuration!
    response = HTTParty.get(endpoint, headers: read_headers, timeout: REQUEST_TIMEOUT_SECONDS)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    { response: sanitized_state!(response) }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def save(paused:, expected_revision:, actor_ref:)
    validate_configuration!
    response = HTTParty.put(endpoint, headers: write_headers(actor_ref), body: {
      expected_revision: expected_revision,
      paused: paused
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    { response: sanitized_state!(response) }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  private

  def sanitized_state!(response)
    state = sanitize_state(JSON.parse(response.body)['state'])
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless state

    state
  end

  def sanitize_state(value)
    return unless valid_state?(value)

    value.slice(*PUBLIC_FIELDS)
  end

  def valid_state?(value)
    value.is_a?(Hash) &&
      [true, false].include?(value['paused']) &&
      (value['paused_at'].nil? || value['paused_at'].is_a?(String)) &&
      valid_actor?(value['paused_by']) &&
      (value['revision'].nil? || value['revision'].is_a?(Integer))
  end

  # `paused_by` chega ao ecra como "pausada por Ana". Um valor gigante vindo do
  # upstream rebentava o cabecalho, e um valor que nao e texto rebentava a
  # traducao — por isso a forma e validada aqui, nao no template.
  def valid_actor?(value)
    value.nil? || (value.is_a?(String) && value.length <= MAX_ACTOR_LENGTH)
  end

  def conflict_response?(response)
    response.code == 409 && JSON.parse(response.body)['error'] == 'pause_state_conflict'
  rescue JSON::ParserError
    false
  end

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint
    "#{service_url.delete_suffix('/')}/internal/chatwoot/pause"
  end

  def read_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id
    }
  end

  def write_headers(actor_ref)
    read_headers.merge(
      'Content-Type' => 'application/json',
      'X-Raevo-Actor-Ref' => actor_ref
    )
  end

  def service_url
    ENV.fetch('RAEVO_AI_SERVICE_URL', nil)
  end

  def service_token
    ENV.fetch('RAEVO_AI_SERVICE_TOKEN', nil)
  end
end
