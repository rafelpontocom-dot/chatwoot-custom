class Api::V1::Accounts::RaevoAi::AssistantNameController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def update
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantNameClient.new(integration: integration).save(
      assistant_name: assistant_name_param,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { state: result.fetch(:response) }
  rescue RaevoAi::AssistantNameClient::Conflict
    render json: { error: 'assistant_name_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_name_unavailable' }, status: :service_unavailable
  end

  private

  # Renomear a secretária muda o que ela diz a todos os pacientes da clínica.
  # Mesma exigência da pausa e do horário: administrador, não agente.
  def authorize_account
    authorize Current.account, :update?
  end

  # Vazio é intenção legítima: repõe o nome por omissão. Por isso não se usa
  # `require` — nulo e cadeia vazia querem dizer a mesma coisa aqui.
  def assistant_name_param
    params[:assistant_name].presence
  end
end
