class Api::V1::Accounts::Calendar::GoogleCalendarConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_resource

  def show
    authorize @calendar_resource, :configure?
    render json: connection_payload
  end

  def authorization_url
    authorize @calendar_resource, :configure?
    render json: { url: KanbanCalendar::GoogleCalendarOauthService.new(resource: @calendar_resource).authorization_url }
  rescue KanbanCalendar::GoogleCalendarApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @calendar_resource, :configure?
    @calendar_resource.kanban_calendar_google_connection&.update!(
      access_token: nil,
      refresh_token: nil,
      expires_at: nil,
      status: 'disconnected',
      last_error: nil
    )
    head :no_content
  end

  def retry
    authorize @calendar_resource, :configure?
    connection = @calendar_resource.kanban_calendar_google_connection
    unless connection&.status == 'error'
      return render json: { message: 'Google Calendar does not have a recoverable error' }, status: :unprocessable_entity
    end

    connection.update!(status: 'connected', last_error: nil)
    KanbanCalendar::BackfillGoogleCalendarConnectionJob.perform_later(connection.id)
    render json: connection_payload
  end

  private

  def fetch_calendar_resource
    @calendar_resource = policy_scope(KanbanCalendarResource).find(params[:resource_id])
  end

  def connection_payload
    connection = @calendar_resource.kanban_calendar_google_connection
    {
      connected: connection&.connected? || false,
      retryable: connection&.status == 'error',
      calendar_id: connection&.calendar_id,
      status: connection&.status || 'disconnected',
      last_error: connection&.last_error,
      last_synced_at: connection&.last_synced_at
    }
  end
end
