class Api::V1::Accounts::RaevoAi::OverviewController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return head :not_found unless integration&.enabled?

    render json: RaevoAi::OverviewClient.new(integration: integration).fetch
  rescue RaevoAi::ConfigurationError
    render json: { error: 'raevo_ai_not_configured' }, status: :service_unavailable
  rescue RaevoAi::UpstreamError
    render json: { error: 'raevo_ai_unavailable' }, status: :bad_gateway
  end

  private

  def authorize_account
    authorize Current.account, :show?
  end
end
