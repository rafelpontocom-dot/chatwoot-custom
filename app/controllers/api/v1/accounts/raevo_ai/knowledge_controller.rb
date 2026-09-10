class Api::V1::Accounts::RaevoAi::KnowledgeController < Api::V1::Accounts::BaseController
  # A base de conhecimento da clínica.
  #
  # Ler é para qualquer pessoa da conta; escrever exige administrador, que é a
  # dona da clínica — o que a Elis diz ao paciente como facto não deve poder ser
  # mudado por quem só atende.
  #
  # EDITAR NÃO PUBLICA: `update` grava rascunho, `publish` é que troca o que a
  # Elis consulta. São ações separadas de propósito, e não um `save` que faz as
  # duas coisas — senão mudar um preço mudava a conversa seguinte sem ninguém
  # ter confirmado nada.
  before_action :authorize_read, only: [:show]
  before_action :authorize_write, only: [:update, :publish, :rollback]
  before_action :set_integration

  MAX_CONFIRMED_KEYS = 50

  def show
    render json: RaevoAi::KnowledgeClient.new(integration: @integration).fetch
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'knowledge_unavailable' }, status: :service_unavailable
  end

  def update
    result = client.save_draft(item: knowledge_item, expected_revision: expected_revision, actor_ref: actor_ref)
    render json: result
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_knowledge_request' }, status: :unprocessable_entity
  rescue RaevoAi::KnowledgeClient::Conflict
    render json: { error: 'knowledge_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'knowledge_unavailable' }, status: :service_unavailable
  end

  def publish
    result = client.publish(
      expected_revision: required_revision,
      confirmed_sensitive_keys: confirmed_sensitive_keys,
      actor_ref: actor_ref
    )
    render json: result
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_knowledge_request' }, status: :unprocessable_entity
  rescue RaevoAi::KnowledgeClient::SensitiveConfirmationRequired => e
    # 428: o pedido está bem formado, falta a clínica confirmar o que muda.
    render json: { error: 'sensitive_confirmation_required', topics: e.topics },
           status: :precondition_required
  rescue RaevoAi::KnowledgeClient::Conflict
    render json: { error: 'knowledge_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'knowledge_unavailable' }, status: :service_unavailable
  end

  def rollback
    render json: client.rollback(version_id: version_id, actor_ref: actor_ref)
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_knowledge_request' }, status: :unprocessable_entity
  rescue RaevoAi::KnowledgeClient::Conflict
    render json: { error: 'knowledge_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'knowledge_unavailable' }, status: :service_unavailable
  end

  private

  def authorize_read
    authorize Current.account, :show?
  end

  def authorize_write
    authorize Current.account, :update?
  end

  def set_integration
    @integration = Current.account.raevo_ai_integration
    return if @integration

    render json: { error: 'raevo_ai_not_configured' }, status: :not_found
  end

  def client
    RaevoAi::KnowledgeClient.new(integration: @integration)
  end

  def actor_ref
    "chatwoot:#{Current.account.id}:#{Current.user.id}"
  end

  def knowledge_item
    raw = params.require(:item).to_unsafe_h.stringify_keys
    raise ActionController::BadRequest unless raw.keys.sort == %w[commercial_profile content id title topic_key]

    validate_item!(raw)
    raw
  end

  def validate_item!(raw)
    raise ActionController::BadRequest unless valid_item?(raw)
  end

  def valid_item?(raw)
    (raw['id'].nil? || raw['id'].is_a?(String)) &&
      raw['topic_key'].to_s.match?(/\A[a-z0-9][a-z0-9_]{0,62}\z/) &&
      raw['title'].to_s.strip.length.between?(1, 160) &&
      raw['content'].to_s.strip.length.between?(1, 4000) &&
      raw['commercial_profile'].to_s.strip.length.between?(1, 60)
  end

  def expected_revision
    value = params[:expected_revision]
    return if value.nil?

    revision = Integer(value, exception: false)
    raise ActionController::BadRequest unless revision&.positive?

    revision
  end

  def required_revision
    expected_revision || raise(ActionController::BadRequest)
  end

  def confirmed_sensitive_keys
    keys = Array(params[:confirmed_sensitive_keys])
    raise ActionController::BadRequest if keys.length > MAX_CONFIRMED_KEYS
    raise ActionController::BadRequest unless keys.all?(String)

    keys
  end

  def version_id
    value = params[:version_id].to_s
    raise ActionController::BadRequest unless value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

    value
  end
end
