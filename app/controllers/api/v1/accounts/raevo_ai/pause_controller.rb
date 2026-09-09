class Api::V1::Accounts::RaevoAi::PauseController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::PauseClient.new(integration: integration).fetch
    render json: { state: result.fetch(:response) }
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'pause_state_unavailable' }, status: :service_unavailable
  end

  def update
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::PauseClient.new(integration: integration).save(
      paused: paused_param,
      expected_revision: expected_revision,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { state: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_pause_state' }, status: :unprocessable_entity
  rescue RaevoAi::PauseClient::Conflict
    render json: { error: 'pause_state_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'pause_state_unavailable' }, status: :service_unavailable
  end

  private

  # Pausar e retomar mudam o atendimento da clinica inteira, entao seguem a
  # mesma exigencia de service_hours: administrador, nao agente.
  def authorize_account
    authorize Current.account, :update?
  end

  # `params[:paused]` chega como string no form-encoded. Aceitar so booleano
  # real rejeitaria o pedido vindo do proprio dashboard; aceitar qualquer coisa
  # transformaria um erro de digitacao em pausa silenciosa da clinica.
  def paused_param
    value = params.require(:paused)
    return true if [true, 'true'].include?(value)
    return false if [false, 'false'].include?(value)

    raise ActionController::BadRequest
  end

  def expected_revision
    value = params[:expected_revision]
    return if value.nil?

    revision = Integer(value, exception: false)
    raise ActionController::BadRequest unless revision&.positive?

    revision
  end
end
