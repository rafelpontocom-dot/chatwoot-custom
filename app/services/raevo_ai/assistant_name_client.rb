# Muda o nome da secretária.
#
# O nome vive no serviço Raevo, não numa coluna daqui, porque é ele que monta o
# prompt — e o prompt é onde o nome tem de entrar. Guardá-lo no Chatwoot mudaria
# o rótulo do ecrã e ela continuaria a apresentar-se como Elis na conversa.
#
# Mesmo contrato dos outros clientes: escrita com o actor, lista branca no
# regresso para o upstream não poder injetar campos que a tela não espera.
class RaevoAi::AssistantNameClient
  class Conflict < StandardError; end

  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze
  PUBLIC_FIELDS = %w[assistant_name effective_name].freeze
  MAX_NAME_LENGTH = 40

  def initialize(integration:)
    @integration = integration
  end

  def save(assistant_name:, actor_ref:)
    validate_configuration!
    response = HTTParty.put(endpoint, headers: write_headers(actor_ref),
                                      body: { assistant_name: assistant_name }.to_json,
                                      timeout: REQUEST_TIMEOUT_SECONDS)
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

  # `effective_name` é o que ela passa a dizer — nunca nulo. `assistant_name` é
  # o que a clínica escolheu, e nulo ali significa «usa o padrão».
  def valid_state?(value)
    value.is_a?(Hash) &&
      valid_name?(value['assistant_name'], allow_nil: true) &&
      valid_name?(value['effective_name'], allow_nil: false)
  end

  def valid_name?(value, allow_nil:)
    return true if value.nil? && allow_nil

    value.is_a?(String) && value.length <= MAX_NAME_LENGTH
  end

  def conflict_response?(response)
    response.code == 409 && JSON.parse(response.body)['error'] == 'assistant_name_conflict'
  rescue JSON::ParserError
    false
  end

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint
    "#{service_url.delete_suffix('/')}/internal/chatwoot/assistant-name"
  end

  def write_headers(actor_ref)
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id,
      'X-Raevo-Actor-Ref' => actor_ref
    }
  end

  def service_url
    ENV.fetch('RAEVO_AI_SERVICE_URL', nil)
  end

  def service_token
    ENV.fetch('RAEVO_AI_SERVICE_TOKEN', nil)
  end
end
