class Api::V1::Accounts::RaevoAi::OpportunityTabsController < Api::V1::Accounts::BaseController
  before_action :fetch_integration
  before_action :authorize_account

  def show
    render json: provisioner.configuration
  end

  def update
    render json: provisioner.configure!(
      enabled: ActiveModel::Type::Boolean.new.cast(opportunity_tab_params[:enabled]),
      board_ids: opportunity_tab_params[:board_ids]
    )
  rescue RaevoAi::OpportunityAiTabProvisioner::InvalidBoard
    render json: { error: 'invalid_opportunity_ai_board' }, status: :unprocessable_entity
  end

  private

  def fetch_integration
    @integration = Current.account.raevo_ai_integration
    return head :not_found unless @integration&.enabled?
  end

  def authorize_account
    authorize Current.account, action_name == 'update' ? :update? : :show?
  end

  def opportunity_tab_params
    params.permit(:enabled, board_ids: []).tap { |permitted| permitted.require(:enabled) }
  end

  def provisioner
    @provisioner ||= RaevoAi::OpportunityAiTabProvisioner.new(integration: @integration)
  end
end
