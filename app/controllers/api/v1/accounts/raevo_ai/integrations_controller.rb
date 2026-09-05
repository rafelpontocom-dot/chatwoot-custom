class Api::V1::Accounts::RaevoAi::IntegrationsController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def create
    integration = Current.account.raevo_ai_integration || Current.account.create_raevo_ai_integration!(
      clinic_id: integration_params[:clinic_id],
      enabled: false
    )

    render json: integration_payload(integration), status: :created
  end

  private

  def authorize_account
    authorize Current.account, :update?
  end

  def integration_params
    params.permit(:clinic_id).tap { |permitted| permitted.require(:clinic_id) }
  end

  def integration_payload(integration)
    {
      'clinic_id' => integration.clinic_id,
      'enabled' => integration.enabled?
    }
  end
end
