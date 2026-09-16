class Api::V1::Accounts::RaevoAi::CrmCatalogsController < Api::V1::Accounts::BaseController
  before_action :fetch_integration
  before_action :authorize_account

  def update
    render json: RaevoAi::CrmCatalogExtensionPublisher.new(integration: @integration).publish!(
      board_key: crm_catalog_params[:board_key],
      fields: crm_catalog_params[:fields],
      stages: crm_catalog_params[:stages]
    )
  rescue RaevoAi::CrmCatalogExtensionPublisher::InvalidCatalog
    render json: { error: 'invalid_crm_catalog' }, status: :unprocessable_entity
  end

  private

  def fetch_integration
    @integration = Current.account.raevo_ai_integration
    return head :not_found unless @integration
  end

  def authorize_account
    authorize Current.account, :update?
  end

  def crm_catalog_params
    params.permit(
      :board_key,
      fields: {},
      stages: {}
    ).tap do |permitted|
      permitted.require(:board_key)
    end
  end
end
