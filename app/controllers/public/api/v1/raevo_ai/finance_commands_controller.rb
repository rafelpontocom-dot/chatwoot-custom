class Public::Api::V1::RaevoAi::FinanceCommandsController < ActionController::API
  before_action :authenticate_integration!
  before_action :enforce_rate_limit!

  def create
    conversation = @integration.account.conversations.find_by!(display_id: charge_params[:conversation_id])
    render json: RaevoAi::FinanceChargeExecutor.new(
      integration: @integration, conversation: conversation, command: charge_params.to_h.symbolize_keys
    ).perform
  rescue *finance_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: finance_status(e)
  end

  private

  def authenticate_integration!
    @integration = RaevoAi::CommandAuthenticator.new(
      clinic_id: request.headers['X-Raevo-Clinic-Id'], token: request.headers['X-Raevo-Command-Token']
    ).authenticate
    render json: { error: 'unauthorized' }, status: :unauthorized unless @integration
  end

  def enforce_rate_limit!
    return if RaevoAi::CommandRateLimiter.new(integration: @integration).allowed?

    render json: { error: 'rate_limited' }, status: :too_many_requests
  end

  def charge_params
    @charge_params ||= params.permit(:action_id, :conversation_id, :board_key, :charge_key, :tax_id).tap do |permitted|
      %i[action_id conversation_id board_key charge_key].each { |key| permitted.require(key) }
    end
  end

  def finance_errors
    [ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, Finance::Asaas::ApiError,
     RaevoAi::FinanceCatalog::InvalidCatalog, RaevoAi::FinanceChargeExecutor::InvalidCharge,
     RaevoAi::CrmCatalog::InvalidCatalog, RaevoAi::CrmCardResolver::AmbiguousCard, RaevoAi::CommandRecorder::Conflict]
  end

  def finance_status(error)
    return :not_found if error.is_a?(ActiveRecord::RecordNotFound)
    return :conflict if error.is_a?(RaevoAi::CommandRecorder::Conflict)

    :unprocessable_entity
  end
end
