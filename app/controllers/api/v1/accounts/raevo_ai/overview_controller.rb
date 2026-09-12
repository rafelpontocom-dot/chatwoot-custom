class Api::V1::Accounts::RaevoAi::OverviewController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return render_state('not_configured') unless integration
    # `enabled` é a bandeira de funcionalidade da conta, não a pausa da Elis —
    # a pausa vive no serviço e tem estado próprio. Chamar «paused» a isto
    # colidia com a pausa a sério assim que ela passou a existir.
    return render_state('disabled') unless integration.enabled?

    overview = RaevoAi::OverviewClient.new(integration: integration).fetch(window_days: window_days)
    render json: {
      connection_state: 'active',
      operational_state: 'healthy',
      overview: overview
    }
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render_state('unavailable')
  end

  private

  def authorize_account
    authorize Current.account, :show?
  end

  # Janela fora das três oferecidas cai em 30 em vez de recusar: um filtro
  # estragado não deve deixar a clínica sem painel.
  def window_days
    dias = params[:days].to_i
    RaevoAi::OverviewClient::WINDOW_DAYS.include?(dias) ? dias : 30
  end

  def render_state(connection_state)
    operational_state = case connection_state
                        when 'active' then 'healthy'
                        when 'unavailable' then 'unavailable'
                        end

    render json: {
      connection_state: connection_state,
      operational_state: operational_state,
      overview: nil
    }
  end
end
