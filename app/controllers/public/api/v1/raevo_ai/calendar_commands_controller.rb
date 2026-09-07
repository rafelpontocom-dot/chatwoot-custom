class Public::Api::V1::RaevoAi::CalendarCommandsController < ActionController::API
  before_action :authenticate_integration!
  before_action :enforce_rate_limit!

  def create
    conversation = @integration.account.conversations.find_by!(display_id: booking_params[:conversation_id])
    render json: RaevoAi::CalendarBookingExecutor.new(
      integration: @integration,
      conversation: conversation,
      command: booking_params.to_h.symbolize_keys
    ).perform
  rescue *calendar_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: calendar_status(e)
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

  def booking_params
    @booking_params ||= params.permit(:action_id, :conversation_id, :board_key, :booking_key, :starts_at).tap do |permitted|
      %i[action_id conversation_id board_key booking_key starts_at].each { |key| permitted.require(key) }
    end
  end

  def calendar_errors
    [ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, RaevoAi::CalendarCatalog::InvalidCatalog,
     RaevoAi::CalendarBookingExecutor::InvalidBooking, RaevoAi::CrmCatalog::InvalidCatalog,
     RaevoAi::CrmCardResolver::AmbiguousCard, RaevoAi::CommandRecorder::Conflict, KanbanCalendar::ConflictError]
  end

  def calendar_status(error)
    return :not_found if error.is_a?(ActiveRecord::RecordNotFound)
    return :conflict if error.is_a?(RaevoAi::CommandRecorder::Conflict) || error.is_a?(KanbanCalendar::ConflictError)

    :unprocessable_entity
  end
end
