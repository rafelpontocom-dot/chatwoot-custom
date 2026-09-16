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
    connection = @calendar_resource.kanban_calendar_google_connection
    connection&.update!(
      access_token: nil,
      refresh_token: nil,
      expires_at: nil,
      status: 'disconnected',
      last_error: nil
    )
    # Desligada a agenda, os compromissos do Google deixam de travar horários.
    KanbanCalendarExternalBusyBlock.where(
      kanban_calendar_resource_id: @calendar_resource.id,
      provider: KanbanCalendar::GoogleCalendarImportService::PROVIDER
    ).delete_all
    head :no_content
  end

  # «Sincronizar agora»: importa já, à espera, para a resposta dizer se o Google
  # aceitou — é o que permite a quem configura ver o motivo de uma falha.
  def sync
    authorize @calendar_resource, :configure?
    connection = @calendar_resource.kanban_calendar_google_connection
    return render json: { message: 'Google Calendar is not connected' }, status: :unprocessable_entity if connection&.access_token.blank?

    connection.update!(status: 'connected', last_error: nil)
    KanbanCalendar::GoogleCalendarImportService.new(connection: connection).perform!
    connection.reload
    KanbanCalendar::BackfillGoogleCalendarConnectionJob.perform_later(connection.id)
    render json: connection_payload
  rescue KanbanCalendar::GoogleCalendarApiError
    connection.reload
    render json: connection_payload, status: :unprocessable_entity
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
      last_synced_at: connection&.last_synced_at,
      last_imported_at: connection&.last_imported_at
    }
  end
end
