class Api::V1::Accounts::RaevoAi::OverviewController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return render_state('not_configured') unless integration
    return render_state('paused') unless integration.enabled?

    overview = RaevoAi::OverviewClient.new(integration: integration).fetch
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
