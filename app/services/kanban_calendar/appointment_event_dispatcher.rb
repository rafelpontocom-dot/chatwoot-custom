class KanbanCalendar::AppointmentEventDispatcher
  EVENT_NAMES = {
    'created' => Events::Types::KANBAN_APPOINTMENT_CREATED,
    'rescheduled' => Events::Types::KANBAN_APPOINTMENT_RESCHEDULED,
    'canceled' => Events::Types::KANBAN_APPOINTMENT_CANCELED,
    'confirmed' => Events::Types::KANBAN_APPOINTMENT_CONFIRMED,
    'completed' => Events::Types::KANBAN_APPOINTMENT_COMPLETED,
    'no_show' => Events::Types::KANBAN_APPOINTMENT_NO_SHOW
  }.freeze

  def initialize(appointment:, event_type:)
    @appointment = appointment
    @event_type = event_type
  end

  def dispatch
    return unless event_name

    dispatch_automation_event if @appointment.kanban_card
    schedule_google_calendar_sync
  end

  private

  def event_name
    EVENT_NAMES[@event_type]
  end

  def dispatch_automation_event
    Rails.configuration.dispatcher.dispatch(event_name, Time.current, event_data)
  end

  def schedule_google_calendar_sync
    return unless @appointment.kanban_calendar_resources.joins(:kanban_calendar_google_connection)
                              .exists?(kanban_calendar_google_connections: { status: 'connected' })

    KanbanCalendar::SyncGoogleCalendarAppointmentJob.perform_later(@appointment.id)
  end

  def event_data
    {
      account_id: @appointment.account_id,
      board_id: @appointment.kanban_card.kanban_board_id,
      card_id: @appointment.kanban_card_id,
      appointment_id: @appointment.id,
      appointment_version: @appointment.appointment_version,
      appointment_status: @appointment.status,
      appointment_starts_at: @appointment.starts_at.iso8601,
      appointment_ends_at: @appointment.ends_at.iso8601,
      event_key: "appointment:#{@appointment.id}:#{@event_type}:v#{@appointment.appointment_version}"
    }
  end
end
