# A base de conhecimento da clínica, vista do Chatwoot.
#
# O que a Elis sabe responder vive no serviço Raevo, não aqui: é lá que está o
# vector e é lá que a busca acontece. Este cliente é a ponte, e a sua obrigação
# principal é de recorte — o que vem de cima traz `embedding`, `claim_key` e
# `source`, que são maquinaria interna e não têm porque chegar ao ecrã da
# clínica. Só passa o que está na allowlist.
#
# A regra de produto que atravessa tudo isto: EDITAR NÃO PUBLICA. `save_draft`
# mexe num rascunho versionado; a base que a Elis consulta só muda em `publish`.
class RaevoAi::KnowledgeClient
  class Conflict < StandardError; end

  # Publicar tocou em assunto delicado que ninguém confirmou. Não é erro: é o
  # serviço a devolver o que falta confirmar, para o ecrã poder perguntar.
  class SensitiveConfirmationRequired < StandardError
    attr_reader :topics

    def initialize(topics)
      @topics = topics
      super('sensitive confirmation required')
    end
  end

  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze

  ITEM_FIELDS = %w[id topic_key title content commercial_profile].freeze
  TOPIC_FIELDS = %w[key label sensitive].freeze
  VERSION_FIELDS = %w[id version_number status created_by published_by published_at item_count].freeze

  MAX_ITEMS = 500
  MAX_VERSIONS = 50

  def initialize(integration:)
    @integration = integration
  end

  def fetch
    corpo = get('')
    {
      topics: sanitize_collection(corpo['topics'], TOPIC_FIELDS, MAX_ITEMS),
      published: sanitize_collection(corpo['published'], ITEM_FIELDS, MAX_ITEMS),
      draft: sanitize_draft(corpo['draft']),
      versions: sanitize_collection(corpo['versions'], VERSION_FIELDS, MAX_VERSIONS)
    }
  end

  def save_draft(item:, expected_revision:, actor_ref:)
    corpo = put('/draft', { expected_revision: expected_revision, item: item }, actor_ref)
    { draft: sanitize_draft(corpo['draft']) }
  end

  def publish(expected_revision:, confirmed_sensitive_keys:, actor_ref:)
    corpo = post('/publish', {
                   expected_revision: expected_revision,
                   confirmed_sensitive_keys: confirmed_sensitive_keys
                 }, actor_ref)
    { active_version: sanitize_hash(corpo['active_version'], VERSION_FIELDS) }
  end

  def rollback(version_id:, actor_ref:)
    corpo = post('/rollback', { version_id: version_id }, actor_ref)
    { active_version: sanitize_hash(corpo['active_version'], VERSION_FIELDS) }
  end

  private

  def get(caminho)
    validate_configuration!
    interpretar(HTTParty.get(endpoint(caminho), headers: read_headers, timeout: REQUEST_TIMEOUT_SECONDS))
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def put(caminho, body, actor_ref)
    validate_configuration!
    interpretar(HTTParty.put(endpoint(caminho), headers: write_headers(actor_ref), body: body.to_json,
                                                timeout: REQUEST_TIMEOUT_SECONDS))
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def post(caminho, body, actor_ref)
    validate_configuration!
    interpretar(HTTParty.post(endpoint(caminho), headers: write_headers(actor_ref), body: body.to_json,
                                                 timeout: REQUEST_TIMEOUT_SECONDS))
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def interpretar(response)
    raise Conflict if conflict?(response)
    raise SensitiveConfirmationRequired, sensitive_topics(response) if sensitive_confirmation?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    JSON.parse(response.body)
  end

  def conflict?(response)
    response.code == 409 && parsed_error(response) == 'knowledge_conflict'
  end

  def sensitive_confirmation?(response)
    response.code == 428 && parsed_error(response) == 'sensitive_confirmation_required'
  end

  def sensitive_topics(response)
    temas = JSON.parse(response.body)['topics']
    temas.is_a?(Array) ? temas.grep(String).first(50) : []
  rescue JSON::ParserError
    []
  end

  def parsed_error(response)
    JSON.parse(response.body)['error']
  rescue JSON::ParserError
    nil
  end

  # O rascunho é `nil` quando a clínica ainda não editou nada — e isso é uma
  # resposta legítima, não uma falha.
  def sanitize_draft(value)
    return unless value.is_a?(Hash) && value['revision'].is_a?(Integer)

    { 'revision' => value['revision'], 'items' => sanitize_collection(value['items'], ITEM_FIELDS, MAX_ITEMS) }
  end

  def sanitize_collection(value, campos, limite)
    return [] unless value.is_a?(Array)

    value.first(limite).filter_map { |linha| sanitize_hash(linha, campos) }
  end

  def sanitize_hash(value, campos)
    return unless value.is_a?(Hash)

    value.slice(*campos).presence
  end

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint(caminho)
    "#{service_url.delete_suffix('/')}/internal/chatwoot/knowledge#{caminho}"
  end

  def read_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id
    }
  end

  def write_headers(actor_ref)
    read_headers.merge('Content-Type' => 'application/json', 'X-Raevo-Actor-Ref' => actor_ref)
  end

  def service_url
    ENV.fetch('RAEVO_AI_SERVICE_URL', nil)
  end

  def service_token
    ENV.fetch('RAEVO_AI_SERVICE_TOKEN', nil)
  end
end
