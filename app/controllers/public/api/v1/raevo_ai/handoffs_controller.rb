class Public::Api::V1::RaevoAi::HandoffsController < ActionController::API
  before_action :authenticate_integration!
  before_action :enforce_rate_limit!

  def create
    result = RaevoAi::HandoffExecutor.new(
      integration: @integration,
      conversation: conversation,
      action_id: handoff_params[:action_id],
      reason: handoff_params[:reason],
      note: handoff_params[:note]
    ).perform

    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not_found' }, status: :not_found
  rescue RaevoAi::CommandRecorder::Conflict
    render json: { error: 'action_conflict' }, status: :conflict
  rescue RaevoAi::HandoffContext::IneligibleInbox, RaevoAi::HandoffContext::InvalidHandoffConfiguration
    render json: { error: 'handoff_ineligible' }, status: :unprocessable_entity
  end

  private

  def authenticate_integration!
    @integration = RaevoAi::CommandAuthenticator.new(
      clinic_id: request.headers['X-Raevo-Clinic-Id'],
      token: request.headers['X-Raevo-Command-Token']
    ).authenticate

    render json: { error: 'unauthorized' }, status: :unauthorized unless @integration
  end

  def conversation
    @integration.account.conversations.find_by!(display_id: handoff_params[:conversation_id])
  end

  def enforce_rate_limit!
    return if RaevoAi::CommandRateLimiter.new(integration: @integration).allowed?

    render json: { error: 'rate_limited' }, status: :too_many_requests
  end

  def handoff_params
    @handoff_params ||= params.permit(:action_id, :conversation_id, :reason, :note).tap do |permitted|
      %i[action_id conversation_id reason note].each { |key| permitted.require(key) }
    end
  end
end
