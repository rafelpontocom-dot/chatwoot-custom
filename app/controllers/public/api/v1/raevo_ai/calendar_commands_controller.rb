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

  def availability
    conversation = @integration.account.conversations.find_by!(display_id: availability_params[:conversation_id])
    render json: RaevoAi::CalendarAvailabilityQuery.new(
      integration: @integration,
      conversation: conversation,
      command: availability_params.to_h.symbolize_keys
    ).call
  rescue *calendar_errors => e
    render json: { error: e.class.name.demodulize.underscore }, status: calendar_status(e)
  end

  def project_external
    conversation = @integration.account.conversations.find_by!(display_id: projection_params[:conversation_id])
    render json: RaevoAi::ExternalCalendarProjectionService.new(
      integration: @integration,
      conversation: conversation,
      command: projection_params.to_h.symbolize_keys
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

  def availability_params
    @availability_params ||= params.permit(:conversation_id, :board_key, :booking_key, :starts_on, :ends_on).tap do |permitted|
      %i[conversation_id board_key booking_key starts_on ends_on].each { |key| permitted.require(key) }
    end
  end

  def projection_params
    @projection_params ||= params.permit(
      :action_id, :conversation_id, :board_key, :booking_key, :provider, :external_id,
      :starts_at, :ends_at, :status, :source_status, :source_updated_at, :source_hash
    ).tap do |permitted|
      %i[action_id conversation_id board_key booking_key provider external_id starts_at status source_hash].each do |key|
        permitted.require(key)
      end
    end
  end

  def calendar_errors
    [ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, RaevoAi::CalendarCatalog::InvalidCatalog,
     RaevoAi::CalendarAvailabilityQuery::InvalidAvailability, RaevoAi::CalendarBookingExecutor::InvalidBooking,
     RaevoAi::ExternalCalendarProjectionService::InvalidProjection,
     RaevoAi::CrmCatalog::InvalidCatalog,
     RaevoAi::CrmCardResolver::AmbiguousCard, RaevoAi::CommandRecorder::Conflict, KanbanCalendar::ConflictError]
  end

  def calendar_status(error)
    return :not_found if error.is_a?(ActiveRecord::RecordNotFound)
    return :conflict if error.is_a?(RaevoAi::CommandRecorder::Conflict) || error.is_a?(KanbanCalendar::ConflictError)

    :unprocessable_entity
  end
end
