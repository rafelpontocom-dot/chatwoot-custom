class KanbanCalendar::GoogleCalendarSyncService
  def initialize(appointment:, connection:, client: nil)
    @appointment = appointment
    @connection = connection
    @client = client || KanbanCalendar::GoogleCalendarClient.new(connection: connection)
  end

  def perform!
    return unless @connection.connected?

    @appointment.status == 'canceled' ? cancel_external_event : sync_active_appointment
    @connection.update!(status: 'connected', last_error: nil, last_synced_at: Time.current)
    record_sync_event
  rescue KanbanCalendar::GoogleCalendarApiError => e
    @connection.update!(status: 'error', last_error: e.message)
    raise
  end

  private

  def sync_active_appointment
    external_event_id ? @client.update_event(external_event_id, @appointment) : store_external_event_id(@client.create_event(@appointment))
  end

  def cancel_external_event
    @client.cancel_event(external_event_id) if external_event_id
  end

  def external_event_id
    @appointment.external_refs.dig('google_calendar', @connection.id.to_s)
  end

  def store_external_event_id(event_id)
    refs = @appointment.external_refs.deep_dup
    refs['google_calendar'] ||= {}
    refs['google_calendar'][@connection.id.to_s] = event_id
    @appointment.update!(external_refs: refs)
  end

  def record_sync_event
    @appointment.kanban_calendar_appointment_events.create!(
      account: @appointment.account,
      event_type: 'external_sync',
      occurred_at: Time.current,
      metadata: { 'provider' => 'google_calendar', 'connection_id' => @connection.id }
    )
  end
end
